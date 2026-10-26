/**
 * Overadmin: a rank above admin. An overadmin has every admin command plus the ones taken
 * away from plain admins -- spawning bots and changing the game speed -- and can clear a
 * pause another admin set.
 *
 * The password is set per server in the server's UDKGame.ini -- never in DefaultMustMod.ini,
 * which ships to every player:
 *
 *   [MustMod.MustModOverAdmin]
 *   OverAdminPassword=something
 *
 * Empty (the default) disables overadmin login entirely. Players log in with
 * "OverAdminLogin <password>"; the flag lives on the controller and is dropped with
 * AdminLogout or on map change, like admin.
 */
class MustModOverAdmin extends Object
	config(Game);

var config string OverAdminPassword;

/** Failed logins allowed per connection before further attempts are ignored. */
const MAX_LOGIN_FAILURES = 5;

static function bool IsEnabled()
{
	return default.OverAdminPassword != "";
}

static function bool CheckPassword(string Password)
{
	return IsEnabled() && Password == default.OverAdminPassword;
}
