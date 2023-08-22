import requests
import json


class CloudGuardService:
    def __init__(self, api_key, api_secret, region):
        self.api_key = api_key
        self.api_secret = api_secret
        self.region = region
        self.domain = self.get_cloudguard_domain()
        self.token = self.get_token()

    def get_cloudguard_domain(self):
        return (
            'https://api.941298424820.dev.falconetix.com/v2'
            if self.region == "us"
            else f'https://api.{self.region}.dome9.com/v2'
        )

    def get_token(self):
        headers = {
            "Content-Type": "application/json",
            "Accept": "*/*"
        }
        try:
            response = requests.post(
                f"{self.domain}/auth/assume-role/jwt",
                headers=headers,
                json={},
                auth=(self.api_key, self.api_secret)
            )
            if response.status_code != 200 and response.status_code != 201:
                raise Exception(f"Failed to get CloudGuard token: {response.text}")
            response_data = response.json()
            return response_data["token"]
        except requests.exceptions.RequestException as e:
            raise Exception(f"Failed to get CloudGuard token: {e}")

    def call_cloudguard_api(self, sub_domain, data):
        headers = {
            "Content-Type": "application/json",
            "Accept": "*/*",
            "Authorization": f"Bearer {self.token}"
        }
        try:
            response = requests.post(
                f"{self.domain}/{sub_domain}",
                data=json.dumps(data),
                headers=headers
            )
            if response.status_code != 200 and response.status_code != 201:
                raise Exception(f"Failed to call CloudGuard API: {response.text}")
            return response
        except requests.exceptions.RequestException as e:
            raise Exception(f"Failed to call CloudGuard API: {e}")

    def cloudguard_onboarding_request(self, data):
        return self.call_cloudguard_api("intelligence/gcp/onboarding", data)

    def cloudguard_offboarding_request(self, project_id):
        data = {
            "cloudAccountId": project_id,
            "vendor": "GCP"
        }
        return self.call_cloudguard_api("view/magellan/disable-magellan-for-cloud-account", data)

    def get_topics_from_gcp(self, project_id):
        body = {
            "projectId": project_id
        }
        response = self.call_cloudguard_api("intelligence/gcp/pubsub-topics", body)
        return response.json()

    def get_connected_topics_from_intelligence(self, project_id):
        body = {
            "projectId": project_id
        }
        response = self.call_cloudguard_api("intelligence/gcp/connected-topics", body)
        return response.json()

    def get_connected_sinks_from_intelligence(self, project_id):
        body = {
            "projectId": project_id
        }
        response = self.call_cloudguard_api("intelligence/gcp/logging-sinks", body)
        return response.json()