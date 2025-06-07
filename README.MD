# Introduction
This is Eurofins Devops engineer assignment. The main purpose is to automate a build and deployement process of a simple helloword API application using GithubActions and Powershell scripting language.
# Project structure
```
    |--
        |-- .github # contains github action pipeline
        |-- app # contains application code
        |-- artifact # contains appication zip
        |-- script # contains scripts
        |-- docker # contains docker file
```
# CI/CD build

![My Diagram](./assets/cicd_diagram.PNG)

# Powershell script to deploy a .Net website
## The script includes the following steps:
- Create a user and group, and grant the appropriate permissions to the application pool identity.
- Create an application pool that runs under the created user.
- Create a website, import the certificate from a PFX file into the machine certificate store (Cert:\LocalMachine\My), and bind the certificate to the website.
- Set the log file path for the website.
- Publish the "hello" application to the specified physical path inside the website directory.
- Create the application under the website and associate it with the application pool.

## Example of running
    ```
        .\deploy-website.ps1 -Password "eurofins" -PfxPassword "eurofins" -BindingHost "localhosttest"
    ```


![alt text](./assets/image.png)
![alt text](./assets/image_2.png)
![alt text](./assets/image_3.png)