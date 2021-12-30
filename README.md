# Admin system

This repository contains the metauni administration tools. If you are running your own server, you should familiarise yourself with the [Roblox rules](https://metauni.org/posts/rules/rules) and [Discord Terms of Service](https://discord.com/terms). If you observe users breaking Roblox rules, for example harrassing other users or engaing in offensive behaviour, you should report them using the Roblox tools that can be accessed via `Escape`.

For less serious matters, you can use the Admin Commands.

## Admin Commands

We have a ChatModule which extends the functionality of the in-game chat commands. Commands can be executed by chosen adminstrators by opening chat and entering the command. The module depends on a permission table stored in a persistent DataStore, which associates each Roblox user ID with a permission level (an integer), and is perserved between server restarts and even when updating your world.

|level|role|about|
|--|--|--|
|<0| banned|Instantly kicked when joining your world|
|0| guest | the default permission level|
|50| scribe|Can still draw when boards turned off|
|254| admin|Can execute all commands|

Each higher role in this hierchary accumulates any abilities of lower (non-negative) roles.

The owner of a private server always has admin privileges. If the creator of an experience is a user, that user will always have admin privileges in any *public* server (not in a private server). If the creator of an experience is a group, the ranks of members of that group will by default determine permissions in any *public* server (not in private servers). For example, in any public metauni server any members of the [metauni Roblox group](https://www.roblox.com/groups/13108882/metauni#!/about) with the Scribe role will have permission level at least `50`. But in a private server only the owner of the server has any nonzero permission level by default.

### Installation

To install AdminCommands, download a release from this GitHub repository and drag the `rbxmx` file into your `Workspace` in Roblox Studio. This will add a folder called `ChatModules` which you should drag into the top-level folder `Chat`. 

### Using commands

Enter your Roblox world to read about and try the commands. When an admin joins, they are reminded they can get a list of commands by chatting `/helpadmin` or command-specific help by adding a `?` after the command, e.g. `/ban?`. The usage of the commands themselves is all documented within Roblox chat itself, so here we will just give an overview.

### Banning

Ban management is achieved using the `/ban`, `/unban`, `/kick`, `/banstatus` commands. `/ban` lowers a players permission level to `-1`, kicks them from the game and rekicks them whenever they rejoin. This is a permanent ban that persists between server restarts and updates, and can be undone by `/unban`, which resets their permission level to `0` (unless they weren't banned). `/banstatus` can be used to check if someone is banned, and `/kick` can be used to kick them from the world temporarily (they can rejoin immediately).

### Whiteboard activation

We encourage administrators to be particularly careful about the use of whiteboards since some usages of these fall outside the Roblox rules (for example, the whiteboards should not be used as an alternative chat system, or used to post Discord links, URLs or offensive images, or in general to bypass the Roblox filtration system). You can use the metauni admin tools to turn whiteboards on or off, so that they are only enabled at particular times under the supervision of administrators or their delegates.

Drawing on whiteboards can be disabled for guests with the `/boards off` command and reactivated with `/boards on`. This setting is preserved between server restarts and updates, so you may choose to leave the boards disabled when you're not around. This setting has no effect on *scribes* and *admins*, so you can assign the *scribe* role to, for example, guest speakers, or anyone you trust without giving them the admin role.

### Roles

Managing roles/permission levels is done via the `/setadmin`, `/setscribe`, `/setguest`, `/setperm`, `/getperm` commands. Chat `/setperm?` or `/getperm?` for a list of roles/permission levels.

### Integration with Roblox groups

You can manage permissions via a Roblox group, using `/setrobloxgroup ID` where `ID` is the identification number of your group, obtained from its URL on the Roblox group page. Use `/setrobloxgroup 0` to disable the link to the Roblox group. The Admin Commands will assign to every player in the experience which is also a group member the permission level given by their rank in the group.

The Admin Commands also looks for special roles `Scribe` and `Admin` in your Roblox group, and uses the ranks of those groups to manage the cutoffs for scribes and admins in your experience (which are by default `50` and `254` respectively).

If the Roblox experience was created by a group, then by default the Admin Commands will import permissions from that group, but you can set a different group using `setrobloxgroup`.

Some notes:

* Note that if you disable the link, permissions from the Roblox group will have already been written into the DataStore, so e.g. any admins in your Roblox group will have admin privileges in your experience *even after you turn off the link* with `/setrobloxgroup 0`. You will have to manually change the permissions to the desired settings.

* If you change the Roblox group permissions the settings in a live server will not immediately change, but you can force them to reload by running `/setrobloxgroup ID` again.

## Generating a Release

The `metaadmin.rbxmx` file is generated like this
```bash
rojo build --output "build.rbxlx"
remodel run admin_packager.lua
```

The first command builds a place file according to `default.project.json`.
The second command uses [remodel](https://github.com/rojo-rbx/remodel) to extract the `ChatModules` folder as an `rbxmx` file.