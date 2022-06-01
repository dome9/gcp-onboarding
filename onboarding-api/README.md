# :cloud: GCP Intelligence Onboarding/Offboarding :cloud:

### This folder contains Python scripts allowing you to:
- Onboard your GCP Project to CloudGuard Intelligence
- Offboard your GCP Project from CloudGuard Intelligence

### GCP Account Activity Logs to Intelligence onboarding flow
The script provided will create the following resources in your GCP project:<br><br>
:one: Service account "cloudguard-logs-authentication"<br>
:two: Topic "cloudguard-topic"<br>
:three: Subscription "cloudguard-subscription"<br>
:four: Sink "cloudguard-sink"<br>

The script will make an API call to CloudGuard to onboard your GCP Project to CloudGuard Intelligence:<br>
- Path: https://api.dome9.com/v2/view/magellan/magellan-gcp-onboarding
- Params: { CloudAccounts: ["your GCP project ID"], "LogType" : "CloudTrail"}
- See example: https://api-v2-docs.dome9.com/#intelligence_gcponboarding

### GCP Network Traffic Logs to Intelligence onboarding flow
The script provided will create the following resources:<br><br>
:one: Service account "cloudguard-logs-authentication"<br>
:two: Topic "cloudguard-fl-topic"<br>
:three: Subscription "cloudguard-fl-subscription"<br>
:four: Sink "cloudguard-fl-sink"<br>

The script will make an API call to CloudGuard to onboard your GCP Project to CloudGuard Intelligence:<br>
- Path: https://api.dome9.com/v2/view/magellan/magellan-gcp-onboarding
- Params: { CloudAccounts: ["your GCP project ID"], "LogType" : "flowlogs"}
- See example: https://api-v2-docs.dome9.com/#intelligence_gcponboarding

Notice: If your flow logs are not enabled, please follow the Intelligence onboarding "Prerequisites" screen on the CloudGuard portal.

### Prerequisites
:one: Make sure you have python installed on your computer.

### Onboarding Steps
:one: Create a service account in GCP with the following permissions (under IAM & ADMIN -> Service Accounts):<br>
- Service Account Admin <br>
- Logging Admin <br>
- Pub/Sub Admin <br>
- Deployment Manager Editor <br>

:two: Choose the service account you created. Add a service account key and download the private key in json format.<br>

:three: Give the following permissions to this user: {accountId}@cloudservices.gserviceaccount.com (under IAM & ADMIN -> IAM):
- Security Admin <br>
- Logging Admin <br>

:four: Create API key in CloudGuard
- Go to Setting -> Credentials and click on 'CREATE API KEY'
- Copy the ID & Secret (Notice: the secret will not be accessible later).

:five: Clone this folder and install the required packages:
- pip install -r requirements.txt

:six: Run onboarding-api.py or offboarding-api.py with the following arguments:
- project_id_arg - Your GCP project name (in lower case)
- region_arg - The CloudGuard region (Data Center) you use:
  - us for United States
  - eu1 for Ireland
  - ap1 for Singapore
  - ap2 for Australia
  - ap3 for India
  - cace1 for Canada
- api_key_arg - Your CloudGuard API key (ID) from step :four:
- api_secret_arg - Your CloudGuard API secret key from step :four:
- client_id_arg - Your CloudGuard client ID (under Setting -> Account Info)
- log_type_arg - NetworkTraffic/AccountActivity (only in onboarding)
- GOOGLE_APPLICATION_CREDENTIALS - The local path to your private key file from step :two:<br>

**Good Luck!**<br>
For any issues or help needed please contact Support as usual or your Customer Success Manager.
