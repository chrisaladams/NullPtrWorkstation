-- nullptr Workstation: beginner help (dashboard tips + cheat sheet window)
local M = {}

M.tips = {
  "Press  i  to type (Insert mode). Press  Esc  to go back to Normal mode.",
  "Save with  :w  then Enter. Quit with  :q . Save and quit:  :wq",
  "Made a mistake?  u  undoes,  Ctrl+r  redoes.",
  "Space e  opens the file explorer. Press  a  in it to add a file,  d  to delete,  r  to rename.",
  "Space f f  finds a file by name.  Space f w  searches text in the whole project.",
  "Space m b  builds,  Space m r  runs,  Space m d  (or F5) debugs the current project.",
  "F9 (or Space d b) toggles a breakpoint on the current line. F10 steps over, F11 steps into.",
  "Press  Space  and wait: a menu shows every shortcut that starts with Space.",
  "Space O  opens the folder as an editable list (Oil): rename files by editing text, then :w",
  "Space g g  opens LazyGit. Space g d  shows a diff of your changes.",
  "Space x x  lists problems in this file (Trouble). Space l S  shows the symbol outline.",
  "Ctrl+b then 2  jumps to the build terminal (tmux).  Ctrl+b then 1  comes back here.",
  "dd  deletes a line,  yy  copies it,  p  pastes it below.",
  "/word  then Enter searches forward;  n  jumps to the next match.",
  "Space ?  opens the nullptr cheat sheet. Type  keys  in any terminal for the same.",
}

function M.tip()
  local i = math.floor(os.time() / 3600) % #M.tips + 1 -- changes every hour
  return "Tip: " .. M.tips[i]
end

local function doc(name)
  for _, dir in ipairs { "/usr/local/share/nullptr/docs", vim.fn.expand "~/.local/share/nullptr/docs" } do
    local p = dir .. "/" .. name
    if vim.uv.fs_stat(p) then return p end
  end
end

--- Open a nullptr doc read-only in a floating window (q closes it)
function M.open(name)
  local path = doc(name or "cheatsheet.txt")
  if not path then return vim.notify("Help file not found: " .. (name or "cheatsheet.txt"), vim.log.levels.ERROR) end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.fn.readfile(path))
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  local w = math.min(110, vim.o.columns - 4)
  local h = math.min(vim.o.lines - 4, 48)
  vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = w, height = h, row = math.floor((vim.o.lines - h) / 2),
    col = math.floor((vim.o.columns - w) / 2), border = "rounded", title = " nullptr help — q to close ",
    title_pos = "center", style = "minimal",
  })
  vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = buf })
  vim.keymap.set("n", "<Esc>", "<Cmd>close<CR>", { buffer = buf })
end

return M
