---@module 'snacks'

---@module 'fff_snacks'

---@alias fff_snacks.GrepMode "plain" | "regex" | "fuzzy"

---@class fff_snacks.GrepConfig: snacks.picker.Config
---@field grep_mode? fff_snacks.GrepMode[]
---@field classify_definitions? boolean
---@field _is_grep_mode_plain? boolean
---@field _is_grep_mode_regex? boolean
---@field _is_grep_mode_fuzzy? boolean

---@class fff_snacks.GrepPicker: snacks.Picker
---@field opts fff_snacks.GrepConfig

local config = require "fff-snacks.config"

local M = {}

M.sources = {
  find_files = require("fff-snacks.find_files").source,
  live_grep = require("fff-snacks.live_grep").source,
}

---Setup fff-snacks with default options
---@param opts? fff_snacks.Config
function M.setup(opts)
  config.setup(opts)
end

---@param opts? snacks.picker.Config
function M.find_files(opts)
  Snacks.picker.pick(config.make_opts("find_files", opts))
end

---@param opts? fff_snacks.GrepConfig
function M.live_grep(opts)
  Snacks.picker.pick(config.make_opts("live_grep", opts))
end

---@param opts? fff_snacks.GrepConfig
function M.grep_word(opts)
  local picker_opts = config.make_opts("grep_word", opts)
  picker_opts = vim.tbl_deep_extend("force", picker_opts or {}, {
    search = function(picker)
      return picker:word()
    end,
  })
  Snacks.picker.pick(picker_opts)
end

return M
