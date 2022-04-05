# :cloud: GCP Intelligence Onboarding/Offboarding with API :cloud:

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

:four: Clone this folder and add the following environment variables:
- GOOGLE_APPLICATION_CREDENTIALS (Value: path to the key) <br>
- PROJECT_ID <br>
- REGION <br>
- API_KEY <br>
- API_SECRET <br>
- CLIENT_ID <br>
- LOG_TYPE <br>

### GCP Account Activity Logs to Intelligence onboarding flow
The script provided will create the following resources:<br><br>
:one: Service account "cloudguard-logs-authentication"<br>
:two: Topic "cloudguard-topic"<br>
:three: Subscription "cloudguard-subscription"<br>
:four: Sink "cloudguard-sink"<br>

![process](./img/gcp.png)

### GCP Network Traffic Logs to Intelligence onboarding flow
The script provided will create the following resources:<br><br>
:one: Service account "cloudguard-logs-authentication"<br>
:two: Topic "cloudguard-fl-topic"<br>
:three: Subscription "cloudguard-fl-subscription"<br>
:four: Sink "cloudguard-fl-sink"<br>

**Good Luck!**
<img src="img/google-cloud-platform-solution-hero-floating-image-400x400-1_(1).png" width=20%>
