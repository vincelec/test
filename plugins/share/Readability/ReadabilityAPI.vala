//	This file is part of FeedReader.
//
//	FeedReader is free software: you can redistribute it and/or modify
//	it under the terms of the GNU General Public License as published by
//	the Free Software Foundation, either version 3 of the License, or
//	(at your option) any later version.
//
//	FeedReader is distributed in the hope that it will be useful,
//	but WITHOUT ANY WARRANTY; without even the implied warranty of
//	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//	GNU General Public License for more details.
//
//	You should have received a copy of the GNU General Public License
//	along with FeedReader.  If not, see <http://www.gnu.org/licenses/>.

namespace FeedReader.ReadabilitySecrets {
	const string base_uri			= "https://www.readability.com/api/rest/v1/";
	const string oauth_consumer_key		= "jangernert";
	const string oauth_consumer_secret	= "3NSxqNW5d6zVwvZV6tskzVrqctHZceHr";
	const string oauth_callback			= "feedreader://readability";
}

public class FeedReader.ReadabilityAPI : ShareAccountInterface, Peas.ExtensionBase {

    private GLib.Settings m_shareSettings;
    public Logger m_logger { get; construct set; }

    public ReadabilityAPI()
    {
        m_shareSettings = new GLib.Settings("org.gnome.feedreader.share");
    }

    public string getRequestToken()
    {
        try
        {
            var oauthObject = new Rest.OAuthProxy (
                ReadabilitySecrets.oauth_consumer_key,
                ReadabilitySecrets.oauth_consumer_secret,
                ReadabilitySecrets.base_uri,
                false);

			oauthObject.request_token("oauth/request_token", ReadabilitySecrets.oauth_callback);
            return oauthObject.get_token();
		}
        catch (Error e)
        {
			m_logger.print(LogMessage.ERROR, "ReadabilityAPI: cannot get request token: " + e.message);
		}

        return "";
    }

    public bool getAccessToken(string id, string verifier)
    {
        try
        {
            var oauthObject = new Rest.OAuthProxy (
                ReadabilitySecrets.oauth_consumer_key,
                ReadabilitySecrets.oauth_consumer_secret,
                ReadabilitySecrets.base_uri,
                false);

			oauthObject.access_token("oauth/access_token", verifier);

            string accessToken = oauthObject.get_token();
    		string secret = oauthObject.get_token_secret();
            string user = "";
            var settings = new Settings.with_path("org.gnome.feedreader.share.account", "/org/gnome/feedreader/share/readability/%s/".printf(id));


            // get username -----------------------------------------------------------------------
            var call = oauthObject.new_call();
    		oauthObject.url_format = "https://www.readability.com/api/rest/v1/";
    		call.set_function("users/_current");
    		call.set_method("GET");
            try
            {
                call.run();
            }
            catch(Error e)
            {
                m_logger.print(LogMessage.ERROR, e.message);
            }
            if(call.get_status_code() == 403)
            {
                return false;
            }
            var parser = new Json.Parser();

            try
            {
                parser.load_from_data(call.get_payload());
            }
            catch(Error e)
            {
                m_logger.print(LogMessage.ERROR, "Could not load response to Message from readability");
                m_logger.print(LogMessage.ERROR, e.message);
            }

            var root_object = parser.get_root().get_object();
            if(root_object.has_member("username"))
                user = root_object.get_string_member("username");
            // -----------------------------------------------------------------------------------------------

            settings.set_string("oauth-access-token", accessToken);
    		settings.set_string("oauth-access-token-secret", secret);
    		settings.set_string("username", user);

            var array = m_shareSettings.get_strv("readability");
    		array += id;
    		m_shareSettings.set_strv("readability", array);

            return true;
		}
        catch(Error e)
        {
			m_logger.print(LogMessage.ERROR, "ReadabilityAPI: cannot get access token: " + e.message);
		}

        return false;
    }

    public bool addBookmark(string id, string url)
    {
        var settings = new Settings.with_path("org.gnome.feedreader.share.account", "/org/gnome/feedreader/share/readability/%s/".printf(id));

        var oauthObject = new Rest.OAuthProxy.with_token (
            ReadabilitySecrets.oauth_consumer_key,
            ReadabilitySecrets.oauth_consumer_secret,
            settings.get_string("oauth-access-token"),
            settings.get_string("oauth-access-token-secret"),
            ReadabilitySecrets.base_uri,
            false);

        var call = oauthObject.new_call();
		oauthObject.url_format = "https://www.readability.com/api/rest/v1/";
		call.set_function ("bookmarks");
		call.set_method("POST");
		call.add_param("url", url);
		call.add_param("favorite", "1");

        call.run_async((call, error, obj) => {
        	m_logger.print(LogMessage.DEBUG, "ReadabilityAPI: status code " + call.get_status_code().to_string());
        	m_logger.print(LogMessage.DEBUG, "ReadabilityAPI: payload " + call.get_payload());
        }, null);
        return true;
    }


    public bool logout(string id)
    {
        var settings = new Settings.with_path("org.gnome.feedreader.share.account", "/org/gnome/feedreader/share/readability/%s/".printf(id));
    	var keys = settings.list_keys();
		foreach(string key in keys)
		{
			settings.reset(key);
		}

        var array = m_shareSettings.get_strv("readability");
    	string[] array2 = {};

    	foreach(string i in array)
		{
			if(i != id)
				array2 += i;
		}
		m_shareSettings.set_strv("readability", array2);
		deleteAccount(id);

        return true;
    }

    public string getURL(string token)
    {
		return	ReadabilitySecrets.base_uri + "oauth/authorize/" + "?oauth_token=" + token;
    }

    public string getIconName()
    {
        return "feed-share-readability";
    }

    public string getUsername(string id)
    {
        var settings = new Settings.with_path("org.gnome.feedreader.share.account", "/org/gnome/feedreader/share/readability/%s/".printf(id));
        return settings.get_string("username");
    }

    public bool needSetup()
	{
		return true;
	}

    public string pluginID()
    {
        return "readability";
    }

    public string pluginName()
    {
        return "Readability";
    }

    public ServiceSetup? newSetup_withID(string id, string username)
    {
        return new ReadabilitySetup(id, this, username);
    }

    public ServiceSetup? newSetup()
    {
        return new ReadabilitySetup(null, this);
    }
}

[ModuleInit]
public void peas_register_types(GLib.TypeModule module)
{
	var objmodule = module as Peas.ObjectModule;
	objmodule.register_extension_type(typeof(FeedReader.ShareAccountInterface), typeof(FeedReader.ReadabilityAPI));
}
