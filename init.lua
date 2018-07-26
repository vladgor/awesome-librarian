--  _ _ _                    _
-- | (_) |__  _ __ __ _ _ __(_) __ _ _ __
-- | | | '_ \| '__/ _` | '__| |/ _` | '_ \
-- | | | |_) | | | (_| | |  | | (_| | | | |
-- |_|_|_.__/|_|  \__,_|_|  |_|\__,_|_| |_|
--
--
-- Copyright (C) 2018 pppp
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option)
-- any later version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
-- FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
-- more details.
--
-- You should have received a copy of the GNU General Public License along with
-- this program.  If not, see <https://www.gnu.org/licenses/>.
--

local awful = require("awful")
local gears = require("gears")
local git = require("librarian.git")

local librarian = {}

local libraries = {}
local libraries_dir = ""

-- @see https://stackoverflow.com/a/40195356
local exists = function (file)
  local ok, _, code = os.rename(file, file)
  if not ok then
    if code == 13 then return true end
  end
  return ok
end

local spawn_synchronously = function(command)
  local handle = io.popen(command)
  local output = handle:read("*all")
  output = output:gsub("%c$", "")
  handle:close()

  return output
end

local notifier = {}

local dir_is_empty = function(dir_path)
  return spawn_synchronously("ls -A " .. dir_path) == ""
end

local remove_file_or_dir = function(path)
  os.execute("rm -rf " .. path)
end

local has_key = function(table, wanted_key)
  for key, _ in pairs(table) do
    if (key == wanted_key) then
      return true
    end
  end

  return false
end

local add_to_package_path = function(library_name)
  local config_dir = gears.filesystem.get_configuration_dir()
  local author = string.match(library_name, "[^/]+")
  package.path = config_dir .. libraries_dir .. author .. "/?/init.lua;" .. package.path
  package.path = config_dir .. libraries_dir .. author .. "/?.lua;" .. package.path
end

local function install_async(library_name, options, callback)
  local notification = notifier.notify({
      title = "Librarian",
      text = "Installing " .. library_name .. " library...",
      timeout = 0,
    })

  git.clone(library_name, options.url, function()
    notifier.replace_text(notification, "Librarian", library_name .. " is installed.")
    notifier.reset_timeout(notification, 5)
    git.checkout(library_name, options.reference or "master")
    callback()
  end)
end

local function install(library_name, options)
  local notification = notifier.notify({
      title = "Librarian",
      text = "Installing " .. library_name .. " library...",
      timeout = 0,
    })

  git.clone(library_name, options.url)

  notifier.replace_text(notification, "Librarian", library_name .. " is installed.")
  notifier.reset_timeout(notification, 5)
end

function librarian.update(library_name)
  local notification = notifier.notify({
      title = "Librarian",
      text = "Updating " .. library_name .. "...",
      timeout = 0,
    })

  git.pull(library_name, function(stdout)
    local message = library_name .. " was updated."
    if (stdout:gsub("%c", "") == "Already up to date.") then
      message = library_name .. " is up to date."
    end
    notifier.replace_text(notification, "Librarian", message)
    notifier.reset_timeout(notification, 5)
  end)
end

function librarian.update_all()
  for library_name, _ in pairs(libraries) do
    librarian.update(library_name)
  end
end

function librarian.is_installed(library_name)
  local config_dir = gears.filesystem.get_configuration_dir()

  return exists(config_dir .. libraries_dir .. library_name .. "/init.lua")
end

function librarian.remove_unused()
  notifier.notify({
      title = "Librarian",
      text = "Removing not used libraries...",
    })

  local libraries_path = gears.filesystem.get_configuration_dir() .. libraries_dir

  local find_command = "cd " .. libraries_path .. " && "
  find_command = find_command .. "find -mindepth 2 -maxdepth 2 -type d"

  awful.spawn.easy_async_with_shell(find_command, function(stdout)
    -- Remove preceding './'s
    local dir_list = stdout:gsub("%./", "")

    for dir in dir_list:gmatch("(.-)%c") do
      if (not has_key(libraries, dir)) then
        notifier.notify({
            title = "Librarian",
            text = "Removing " .. dir .. "...",
            timeout = 1,
          })
        remove_file_or_dir(libraries_path .. dir)

        local parent_dir = libraries_path .. dir:gsub("[^/]+$", "")
        if (dir_is_empty(parent_dir)) then
          remove_file_or_dir(parent_dir)
        end
      end
    end
  end)
end

function librarian.require_async(library_name, options)
  options = options or {}
  libraries[library_name] = options
  local do_after_callback = options["do_after"]

  local install_callback = function()
    local library = require(libraries_dir .. library_name)
    if (do_after_callback) then
      do_after_callback(library)
    end
  end

  add_to_package_path(library_name)
  if (not librarian.is_installed(library_name)) then
    install_async(library_name, options, install_callback)

    return nil
  end

  git.checkout(library_name, options.reference or "master", install_callback)
end

function librarian.require(library_name, options)
  options = options or {}
  libraries[library_name] = options

  if (not librarian.is_installed(library_name)) then
    install(library_name, options)
  end

  git.checkout(library_name, options.reference or "master")
  add_to_package_path(library_name)

  local library = require(libraries_dir .. library_name)
  local do_after_callback = options["do_after"]
  if (do_after_callback) then
    do_after_callback(library)
  end

  return library
end

function librarian.init(options)
  libraries_dir = options.libraries_dir or "libraries/"
  notifier = options.notify or require('librarian.notifier')

  local libraries_path = gears.filesystem.get_configuration_dir() .. libraries_dir .. "/"
  if (not exists(libraries_path)) then
    os.execute("mkdir -p " .. libraries_path)
  end

  git.init({libraries_path = libraries_path})
end

return librarian
