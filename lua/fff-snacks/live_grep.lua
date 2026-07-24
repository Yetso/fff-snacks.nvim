-- maps to require("fff").live_grep()

local M = {}

local conf = require "fff.conf"
local file_picker = require "fff.file_picker"

---@param it snacks.picker.Item?
local function is_decor(it)
  return it and it.decor ~= nil
end

--- override `List:format` so decor items won't get matched against query and change color
local List = require "snacks.picker.core.list"
local orig = List.format
function List:format(item)
  if item.decor then
    return Snacks.picker.highlight.to_text(item.decor)
  end
  return orig(self, item)
end

--- Resolve grep modes from picker opts override, fff config, or fallback defaults
---@param picker_opts table
---@return string[]
local function get_grep_modes(picker_opts)
  local fff_config = conf.get()
  return picker_opts.grep_mode
    or vim.tbl_get(fff_config, "grep", "modes")
    or {
      "plain",
      "regex",
      "fuzzy",
    }
end

-- for on_change step over decor items
local last_cursor = 1

---@type fff_snacks.GrepConfig
M.opts = {
  source = "FFFgrep",
  title = "FFF Live Grep",
  live = true,

  ---@param opts fff_snacks.GrepConfig
  finder = function(opts, ctx)
    if ctx.filter.search == "" then
      return {}
    end

    local cwd = opts.cwd or vim.fn.getcwd()

    local grep_result = require("fff").content_search(ctx.filter.search, {
      mode = get_grep_modes(opts)[1],
      cwd = cwd,
      classify_definitions = opts.classify_definitions or false,
    })

    -- custom snacks decor item
    ---@type snacks.picker.finder.Item
    local definition_separator_item = {
      text = "",
      decor = {
        { "──", "SnacksPickerBorder" },
        { " ↑ Definitions ", "Debug" },
        {
          string.rep("─", 200),
          "SnacksPickerBorder",
        },
      },
    }

    ---@type snacks.picker.finder.Item[]
    local items = {}
    for idx, fff_item in ipairs(grep_result.items) do
      assert(fff_item.line_number, "Expected line_number in grep result item")
      fff_item.match_ranges = fff_item.match_ranges or {}

      local pos
      local end_pos
      if #fff_item.match_ranges == 0 then
        pos = { fff_item.line_number, 0 }
        end_pos = nil
      else
        pos = { fff_item.line_number, fff_item.match_ranges[1][1] }
        end_pos = { fff_item.line_number, fff_item.match_ranges[1][2] }
      end

      local positions = {}
      for _, range in ipairs(fff_item.match_ranges) do
        for i = range[1] + 1, range[2] do
          positions[#positions + 1] = i
        end
      end

      ---@type snacks.picker.finder.Item
      local item = {
        idx = idx,
        cwd = cwd,
        file = fff_item.relative_path,
        line = fff_item.line_content,

        pos = pos,
        end_pos = end_pos,
        positions = positions,

        score = fff_item.total_frecency_score,
        text = ("%s:%d:%d:%s"):format(fff_item.relative_path, pos[1], pos[2], fff_item.line_content),
      }

      -- add a separator when the previous one is definition, but this one isn't
      -- it seems that the definition items are always returned first
      if not fff_item.is_definition and idx > 1 and grep_result.items[idx - 1].is_definition then
        items[#items + 1] = definition_separator_item
      end

      items[#items + 1] = item
    end

    return items
  end,

  -- intercept format and preview handling for decor items
  format = function(item, picker)
    if is_decor(item) then
      return item.decor
    end
    return Snacks.picker.format.file(item, picker)
  end,
  preview = function(ctx)
    if is_decor(ctx.item) then
      return ctx.preview:reset()
    end
    return Snacks.picker.preview.file(ctx)
  end,

  -- move the cursor past decor items, in the direction it was moving
  on_change = function(picker, item)
    local list = picker.list
    if is_decor(item) then
      local dir = list.cursor >= last_cursor and 1 or -1
      local to = list.cursor + dir
      if to < 1 or to > list:count() then
        dir = -dir
      end
      return list:_move(dir) -- this triggers on_change again, so runs of decor items are skipped too
    end
    last_cursor = list.cursor
  end,

  toggles = {
    --- for showing the current grep mode next to the title
    _is_grep_mode_plain = { icon = "plain", value = true },
    _is_grep_mode_regex = { icon = "regex", value = true },
    _is_grep_mode_fuzzy = { icon = "fuzzy", value = true },
  },

  ---@param picker fff_snacks.GrepPicker
  on_show = function(picker)
    -- fff.picker_ui: initialize_picker
    if not file_picker.is_initialized() then
      if not file_picker.setup() then
        vim.notify("Failed to initialize file picker", vim.log.levels.ERROR)
        return
      end
    end

    local modes = get_grep_modes(picker.opts)

    picker.opts.grep_mode = modes
    picker.opts._is_grep_mode_plain = modes[1] == "plain"
    picker.opts._is_grep_mode_regex = modes[1] == "regex"
    picker.opts._is_grep_mode_fuzzy = modes[1] == "fuzzy"
  end,

  actions = {
    ---@param picker fff_snacks.GrepPicker
    cycle_grep_mode = function(picker)
      local modes = get_grep_modes(picker.opts)

      local new_modes = vim.deepcopy(modes)
      -- move the first mode to the end of the list
      local first_mode = new_modes[1]
      table.remove(new_modes, 1)
      new_modes[#new_modes + 1] = first_mode

      picker.opts.grep_mode = new_modes
      picker.opts._is_grep_mode_plain = new_modes[1] == "plain"
      picker.opts._is_grep_mode_regex = new_modes[1] == "regex"
      picker.opts._is_grep_mode_fuzzy = new_modes[1] == "fuzzy"

      picker:refresh()
    end,

    --- ignore decor items for common builtin actions
    confirm = function(picker, item, action)
      if is_decor(item) then
        return
      end
      return Snacks.picker.actions.jump(picker, item, action)
    end,
    select_and_next = function(picker)
      if not is_decor(picker:current()) then
        picker.list:select()
      end
      picker.list:_move(vim.v.count1)
    end,
    select_all = function(picker)
      picker.list:set_selected(vim.tbl_filter(function(i)
        return not is_decor(i)
      end, picker.list.items))
    end,
  },

  win = {
    input = {
      keys = {
        ["<S-Tab>"] = { "cycle_grep_mode", mode = { "n", "i" }, nowait = true },
      },
    },
  },
}

return M
