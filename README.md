# :cloud: GCP Intelligence Onboarding :cloud:

### This repository contains the scripts to run in Google Cloud Shell in order to enable Intelligence for your project.

Onboarding Activity Logs to Intelligence process:

![process](img/gcp.png)

### ⚠️Important notes

- please make sure that you are logged in to your GCP account
- At first you will be asked to trust our repo. Please make sure to confirm.<br>
<img src="img/3.png" width=50%>

Follow the instructions on the right panel: <br>
:one: choose the project id you wish to onboard <br>
<img src="img/2.png" width=50%>

:two: run the script (copy to the terminal and ENTER)<br>
<img src="img/1.png" width=50%>
    
:three: During the deployment your project will be set as default and you will be asked to authorize cloud shell.<br>
<img src="img/Untitled.png" width=50%>
    
:four: :warning: <b>In case this is not your fisrt time onboarding the project : </b>:warning: <br>
The script will run a clean up before creating all cloudguard resources.
Make sure to consent to the deletion in the terminal window. <br><br>
:five: If successful the terminal should output:
```diff
+ Successfully Onboarded.
```

**Good Luck!** 

<img src="img/google-cloud-platform-solution-hero-floating-image-400x400-1_(1).png" width=20%>
