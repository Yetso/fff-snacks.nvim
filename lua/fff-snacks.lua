---@module 'snacks'

---@module 'fff_snacks'

---@alias fff_snacks.GrepMode "plain" | "regex" | "fuzzy"

---@class fff_snacks.GrepConfig: snacks.picker.Config
---@field grep_mode? fff_snacks.GrepMode[]
---@field _is_grep_mode_plain? boolean
---@field _is_grep_mode_regex? boolean
---@field _is_grep_mode_fuzzy? boolean

---@class fff_snacks.GrepPicker: snacks.Picker
---@field opts fff_snacks.GrepConfig

local config = require "fff-snacks.config"

local M = {}

M.sources = {
  FFFfiles = require("fff-snacks.find_files").opts,
  FFFgrep = require("fff-snacks.live_grep").opts,
}

---@param opts? fff_snacks.Config
function M.setup(opts)
  config.setup(opts)
  require("snacks").config.picker.sources.FFFfiles = config.get_config().FFFfiles
  require("snacks").config.picker.sources.FFFgrep = config.get_config().FFFgrep
end

function M.find_files(opts)
  opts = opts or {}
  opts.source = "FFFfiles"
  Snacks.picker.pick(opts)
end

function M.live_grep(opts)
  opts = opts or {}
  opts.source = "FFFgrep"
  Snacks.picker.pick(opts)
end

return M
