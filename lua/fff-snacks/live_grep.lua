-- maps to require("fff").live_grep()

local M = {}

local conf = require "fff.conf"
local file_picker = require "fff.file_picker"

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

---@type fff_snacks.GrepConfig
M.opts = {
  source = "FFFgrep",
  title = "FFF Live Grep",
  format = "file",
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
    })

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

      items[#items + 1] = item
    end

    return items
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
      local first_mode = table.remove(new_modes, 1)
      new_modes[#new_modes + 1] = first_mode

      picker.opts.grep_mode = new_modes
      picker.opts._is_grep_mode_plain = new_modes[1] == "plain"
      picker.opts._is_grep_mode_regex = new_modes[1] == "regex"
      picker.opts._is_grep_mode_fuzzy = new_modes[1] == "fuzzy"

      picker:refresh()
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
