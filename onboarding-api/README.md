# :cloud: GCP Intelligence Onboarding/Offboarding :cloud:

### This folder contains Python scripts allowing you to:
- Onboard your GCP Project to CloudGuard Intelligence
- Offboard your GCP Project from CloudGuard Intelligence

### Onboarding Steps

:one: Create an account service in GCP with the following permissions: <br>
- Service Account Admin <br>
- Logging Admin <br>
- Pub/Sub Admin <br>
- Deployment Manager Editor <br>

:two: Create a key. <br>

:three: Give the following permissions to this user: {accountId}@cloudservices.gserviceaccount.com:
- Security Admin <br>
- Logging Admin <br>

:four: Clone this folder and add the following environment variables(change to arguments):
- GOOGLE_APPLICATION_CREDENTIALS (Value: path to the key) <br>

: five: Install the requirments

:six: Run onboarding-api.py/offboarding-api.py with the following arguments:
- project_id_arg - Your GCP project <br>
- region_arg - The CloudGuard region you use
- api_key_arg - The
- api_secret_arg - The
- client_id_arg - The CloudGuard client ID
- log_type_arg - flowlogs/CloudTrail (only in onboarding) <br>

### GCP Account Activity Logs to Intelligence onboarding flow
The script provided will create the following resources in your GCP project:<br><br>
:one: Service account "cloudguard-logs-authentication"<br>
:two: Topic "cloudguard-topic"<br>
:three: Subscription "cloudguard-subscription"<br>
:four: Sink "cloudguard-sink"<br>

The script will make an API call to CloudGuard to onboard your GCP Project to CloudGuard Intelligence.<br><br>
: Path: https://api.941298424820.dev.falconetix.com/v2/view/magellan/magellan-gcp-onboarding
: Params: { CloudAccounts: ["your GCP project ID"], "LogType" : "CloudTrail"}

### GCP Network Traffic Logs to Intelligence onboarding flow
The script provided will create the following resources:<br><br>
:one: Service account "cloudguard-logs-authentication"<br>
:two: Topic "cloudguard-fl-topic"<br>
:three: Subscription "cloudguard-fl-subscription"<br>
:four: Sink "cloudguard-fl-sink"<br>

The script will make an API call to CloudGuard to onboard your GCP Project to CloudGuard Intelligence.<br><br>
: Path: https://api.941298424820.dev.falconetix.com/v2/view/magellan/magellan-gcp-onboarding
: Params: { CloudAccounts: ["your GCP project ID"], "LogType" : "flowlogs"}

**Good Luck!**
