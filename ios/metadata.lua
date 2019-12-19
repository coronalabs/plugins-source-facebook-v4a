local metadata =
{
	plugin =
	{
		format = 'staticLibrary',
		staticLibs = { 'plugin_facebook', },
		frameworks = { 'Accounts', 'FBSDKCoreKit',  'FBSDKLoginKit', 'FBSDKShareKit', },
		frameworksOptional = {},
		delegates = { 'CoronaFacebookDelegate' }
		-- usesSwift = true,
	},
}

return metadata
