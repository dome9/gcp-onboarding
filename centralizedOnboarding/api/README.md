# Centralized GCP Onboarding and Offboarding :cloud:

This repository contains Python scripts for onboarding and offboarding projects to/from a centralized GCP Pub/Sub setup using CloudGuard.
The scripts facilitate the process of setting up the necessary resources, creating sinks and configuring logging to a centralized Pub/Sub topic.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Authentication](#authentication)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)


## Prerequisites
1. Make sure you have python installed on your computer.

## Installation

1. Clone this repository to your local machine:

   ```bash
   git clone https://github.com/dome9/gcp-onboarding

2. Enter centralizedOnboarding/api:

   ```bash
   cd centralizedOnboarding/api
   
3. Install the required Python dependencies:
    ```bash
   pip install -r requirements.txt

## Authentication
### Create an API key in CloudGuard:

1. Go to Settings -> Credentials.
2. Click on CREATE API KEY.
3. Copy the ID & Secret (Note: The secret will not be accessible later).

### Create a Service Account in GCP and grant the following permissions:
- In the centralized project, assign the following roles to the service account:
    - Editor
    - Pub/Sub Admin
    - Logging Admin
- In the projects you want to onboard, assign the Logging Admin role to the service account.
- Create a new JSON key pair and save it.

## Usage

The following command-line arguments are available for both types of onboarding and offboarding scripts. Replace the placeholders with appropriate values.

### Common Arguments

- `--projects-to-onboard`: Projects you want to onboard as a single string separated by spaces.
- `--region`: The CloudGuard region (Data Center) you use:
    - `us` for United States
    - `eu1` for Ireland
    - `ap1` for Singapore
    - `ap2` for Australia
    - `ap3` for India
    - `cace1` for Canada
- `--log-type`: Onboarding type:
    - `NetworkTraffic` for Flowlogs
    - `AccountActivity` for Account Activity
- `--enable-auto-discovery`: Flag to enable auto onboarding:
    - `True`
    - `False`
- `--api-key`: Your CloudGuard API key created in Authentication step.
- `--api-secret`: Your CloudGuard API secret key created in Authentication step.
- `--google-credentials-path`: The path to your service account JSON key file created in Authentication step.

### Onboarding with Existing Pub/Sub
- `--pubsub-topic`: The GCP Pub/Sub topic name to connect (for example: 'projects/projectId/topics/topicName').

    ```bash
    python existingPubSubOnboarding.py --projects-to-onboard project1 project2 --region us --pubsub-topic projects/projectId/topics/topicName --log-type NetworkTraffic --enable-auto-discovery true --api-key API_KEY --api-secret API_SECRET --google-credentials-path path/to/credentials.json

### Onboarding with New Pub/Sub
- `--project-id`: Your GCP centralized project id.

    ```bash
    python newPubSubOnboarding.py --project-id centralized-project --projects-to-onboard project1 project2 --region us --log-type AccountActivity --enable-auto-discovery true --api-key API_KEY --api-secret API_SECRET --google-credentials-path path/to/credentials.json

### Offboarding:
- `--project-id`: Your GCP project id.
    ```bash
    python offboarding.py --project-id centralized-project --region us --api-key API_KEY --api-secret API_SECRET --google-credentials-path path/to/credentials.json

## Troubleshooting
For any issues or help needed please contact Support as usual or your Customer Success Manager.