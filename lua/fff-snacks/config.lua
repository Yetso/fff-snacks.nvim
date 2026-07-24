local M = {}

---@class fff_snacks.Config
---@field FFFfiles? snacks.picker.Config Default options for find_files
---@field FFFgrep? fff_snacks.GrepConfig Default options for live_grep

---@type fff_snacks.Config
local config = {
  FFFfiles = require("fff-snacks.find_files").opts,
  FFFgrep = require("fff-snacks.live_grep").opts,
}

---@param opts? fff_snacks.Config
function M.setup(opts)
  if not opts then
    return
  end
  config.FFFfiles = vim.tbl_deep_extend("force", config.FFFfiles, opts.FFFfiles or {})
  config.FFFgrep = vim.tbl_deep_extend("force", config.FFFgrep, opts.FFFgrep or {})
end

---@return fff_snacks.Config
function M.get_config()
  return config
end

return M
