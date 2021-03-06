local awful = require("awful")
local utils = require("librarian.utils")

local git = {}

local libraries_dir = ""
local is_init = false

local git_command = "GIT_TERMINAL_PROMPT=0 LC_ALL=en_US.UTF-8 git"

function git.clone(library_name, url, callback)
  local command = git_command .. " clone "
  url = url or "https://github.com/" .. library_name .. ".git"
  command = command .. url

  local path_to_library = libraries_dir .. library_name .. "/"
  command = command .. " " .. path_to_library

  if (callback) then
    awful.spawn.easy_async_with_shell(command, callback)

    return
  end

  utils.spawn_synchronously(command)
end

function git.checkout(library_name, reference, callback)
  local path_to_library = libraries_dir .. library_name .. "/"
  local command = "cd " .. path_to_library .. " && " .. git_command .. " checkout " .. reference

  if (callback) then
    awful.spawn.easy_async_with_shell(command, callback)

    return
  end

  utils.spawn_synchronously(command)
end

function git.pull(library_name, callback)
  local path_to_library = libraries_dir .. library_name .. "/"
  local command = "cd " .. path_to_library .. " && " .. git_command .. " pull"

  if (callback) then
    awful.spawn.easy_async_with_shell(command, callback)

    return
  end

  utils.spawn_synchronously(command)
end

function git.is_init()
  return is_init
end

function git.init(options)
  libraries_dir = options.libraries_dir or ""
  is_init = true
end

return git
