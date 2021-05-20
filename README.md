# AWS CLI Profile Credential Helpers

This repository provides a handful of Bash and Python scripts to make it easy
to switch between multiple AWS profiles while handling credentials in a secure
fashion.

It current supports acquiring credentials using a source profile whose credentials
are stored in the operating system keychain, or via a federated provider such as
AWS SSO, Azure AD, or Okta.


## Getting Started


### Prerequisites

The script requires [Python 3](https://www.python.org/downloads/) to execute. Once it
is setup, install Python package dependencies with `pip3 install -r requirements.txt`.

The following are optional components and only need to be installed if the corresponding
functionality is needed. Instructions for each can be found at the corresponding links.

*  [AWS CLI version 2](https://aws.amazon.com/cli/) - Fetches credentials using AWS SSO
*  [aws-azure-login](https://github.com/sportradar/aws-azure-login) - Fetches credentials using Azure AD
*  [aws-vault](https://github.com/99designs/aws-vault) - Uses credentials stored in the local operating system keychain
*  [gimme-aws-creds](https://github.com/Nike-Inc/gimme-aws-creds) - Fetches credentials using Okta


### Installation

#### Script Placement

The scripts can be executed in place, but for convenience they can be copied to a location
in the system path (e.g. `/usr/local/bin`). The `aws-profile` script is a bit different; it
must be sourced since it needs to set an environment variable. The easiest way to do this
is to add the content of the `aws-profile` file to `~/.bashrc` or `~/.bash_profile`.

To enable Bash completion on the scripts (highly recommended for ease of use), copy the
`aws-profile-completion.bash` configuration to `/usr/local/etc/bash_completion.d/`; note
this assumes that Bash completion is set up properly.

On Linux/MacOS systems, run `./install.sh` to execute the copy, and insert the `aws-profile`
function into the Bash profile. These steps can alternatively be executed manually.

#### Profile Configuration

Once the prerequisites have been installed, they need to be configured. The primary configuration
is stored in the AWS CLI config file at `~/.aws/config` or `%HOMEPATH%\.aws\config`. Each profile
should be listed in this file, per [typical CLI config](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).
Do not create a `credentials` file, this will be done automatically by the credential refresher.

Each profile should at minimum specify a default region. The additional required parameters
depend on the back-end method used to fetch credentials:

*  For profiles that use an IAM user with long-term credentials, there should not be any other
   options given (see the `user-profile` in the example below). To load the credentials into
   the operating system keychain, run `aws-vault add <profile-name>` and follow the prompts.

*  For profiles that assume a role via a source profile, add the `source_profile` value to
   reference them, and the `role_arn` to be assumed. Note that the role must have a trust policy
   that allows the user in the source profile to assume it. See the `role-profile` example below.
   Also ensure the named source profile also has an entry in the config file.

*  For profiles that use AWS SSO, configure the profile per the [instructions](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html),
   i.e. with the `sso_start_url`, `sso_region`, `sso_account_id`, and `sso_role_name` fields.
   See also the `sso-profile` example below.

*  For Azure AD profiles, add `azure_tenant_id`, `azure_app_id_uri`, `azure_default_username`,
   `azure_default_role_arn`, `azure_default_duration_hours`, and `azure_default_remember_me`
   fields as shown in the `azure-profile` example. This can be done most easily by simply
   running `aws-azure-login --configure --profile PROFILE_NAME`. More information on how
   to obtain these values for your application can be found in the
   [aws-azure-login](https://github.com/sportradar/aws-azure-login) documentation. Note
   that if the app URL contains a pound sign (`#`) it needs to be escaped with a backslash
   in the config file (see the example).

*  For Okta profiles, add `okta_profile`, `okta_account_id`, and `okta_role_name` fields
   as shown in the `okta-profile` example. These values should match what's configured in
   the `gimme-aws-creds` config file stored at `~/.okta_aws_login_config`.

An example profile configuration is below:

```
[default]
output=json

[profile user-profile]
region = us-west-2

[profile role-profile]
source_profile = user-profile
role_arn = arn:aws:iam::123456789100:role/example

[profile sso-profile]
sso_start_url = https://example-domain.awsapps.com/start
sso_region = us-west-2
sso_account_id = 123456789100
sso_role_name = ExampleRole

[profile azure-profile]
azure_tenant_id=deadbeef-1234-1234-1234-deadbeef1234
azure_app_id_uri=https://signin.aws.amazon.com/saml\#1
azure_default_username=user@example.com
azure_default_role_arn=arn:aws:iam::123456789100:role/example
azure_default_duration_hours=1
azure_default_remember_me=true

[profile okta-profile]
okta_profile = example
okta_account_id = 123456789100
okta_role_name = ExampleRole
```

#### Okta Configuration

A `~/.okta_aws_login_config` file must be set up if any Okta-backed profiles are configured
(this step can be skipped if not). Run `gimme-aws-creds --action-configure` and follow the
prompts. An example file is below. Precise configuration will vary, but a few key items:

*  Each Okta profile name (the part in brackets) must match the `okta_profile` value in the AWS CLI config
*  The `cred_profile` value should match the corresponding profile name in the AWS CLI config
*  The `write_aws_creds` field should be false (the credential refresher will take care of saving them)
*  The `output_format` must be `json` so the credential refresher can parse the output

```
[example]
okta_username = user@example.com
okta_org_url = https://example-domain.okta.com
app_url = https://example-domain.okta.com/home/amazon_aws/0123456789abcdefABCD/123
gimme_creds_server = appurl
preferred_mfa_type = push
remember_device = True
device_token = 1234567890abcABC-defgABCD
resolve_aws_alias = False
write_aws_creds = False
cred_profile = okta-profile
output_format = json
```


### Running

The following commands are provided:

*  `aws-profile [PROFILE_NAME]` - If run without a parameter, this function parses all
   profile names from the config file and lists them, highlighting the active one (i.e.
   the value of the `AWS_PROFILE` variable). If run with a profile name as a parameter,
   it sets the `AWS_PROFILE` variable to that name, which is the common way that the AWS
   CLI and other tools read a default profile. This prevents needing a `--profile` switch
   on every CLI command. Note that if the completion config was installed `aws-profile`
   can do tab-completion when entering a profile name parameter.

*  `aws-whoami` - Prints user/role details that the CLI is currently configured to use.

*  `aws-console [SERVICE_SLUG]`: Opens the AWS console in a browser, automatically logs in
   to the configured profile, and navigates to the service page indicated by `SERVICE_SLUG`
   (e.g. `s3`, `ec2`, `iam`, `vpc`; see `aws-console-completion.bash` for all options).

*  `aws-refresh-credentials [PROFILE_NAME] [PROFILE_NAME] ...` - Automatically fetches
   temporary credentials for the given profiles and populates the credentials file (i.e.
   `~/.aws/credentials`) with the values, so they're available for the AWS CLI and any
   other tools that shared their config (e.g. boto3). Note that in addition to the provided
   profile names on the command line, the profile set in `AWS_PROFILE` will also be fetched;
   thus when working in a terminal window with a valid profile set with `aws-profile`, this
   script can be run without any parameters to quickly get that profile a set of credentials.
   If no `AWS_PROFILE` is set, and the script is run without any parameters, it will refresh
   credentials for _all_ profiles in the config.

Note that if required, there may prompts for additional information during the credential
refresh (e.g. keychain password for locally-stored credentials, password and MFA prompts for
the SSO profiles). These can happen either in the terminal, or they may open a browser tab,
depending on the particular back-end implementation. The script will wait for entry before
proceeding.


## Contributing

Pull requests are welcomed, especially ones that add support for new credential fetching methods.

Please lint all changes with `flake8 --max-line-length=120` before submitting. Also review
the [Contributing Guidelines](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md).


## Authors

*  Jud Neer (judneer@amazon.com)


## License

This project is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file for details.
