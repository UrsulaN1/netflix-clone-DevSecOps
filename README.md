
# DevSecOps Project - Deploy Netflix Clone Application on AWS using Jenkins

## ⚠️ Important Project Disclaimers

> [!IMPORTANT]
> Please read the following notices carefully before deploying, sharing, or exploring this repository.

---

> **Educational use only.** This is an unofficial streaming UI created to demonstrate DevSecOps workflows. It is not affiliated with or endorsed by Netflix. It uses TMDB metadata when you provide a TMDB v3 API key and is not endorsed or certified by TMDB.

### 🛡️ Production vs. Lab Environment Guidance

This project is configured as a **practical lab guide**. Running all tools on a single host is intended for isolated testing and learning.

For **production workloads**, you must adhere to the following architecture hardening standards:

* **Decoupled Architecture:** Place Jenkins, SonarQube, monitoring suites (Prometheus/Grafana), and the core application on separate dedicated hosts or managed services.
* **In-Transit Security:** Enforce HTTPS/TLS across all public and internal service endpoints.
* **Network Segmentation:** Heavily restrict network access using strict firewall rules, security groups, and private subnets.
* **Data Protection:** Encrypt all persistent storage volumes at rest.
* **Supply Chain Security:** Pin all software versions, package dependencies, and base container image tags to immutable versions.

## I. OVERVIEW

This project demonstrates an end-to-end DevSecOps workflow for deploying a React-based Netflix clone on AWS.

The workflow uses Jenkins for continuous integration and deployment, SonarQube for static code analysis, OWASP Dependency-Check and Trivy for vulnerability scanning, Docker for packaging and deployment, and Prometheus with Grafana for monitoring.

The guide also includes an optional Kubernetes and Argo CD phase for teams that want to move from a single EC2 deployment to GitOps-based delivery on Amazon EKS.

![Logo](./public/assets/DevSecOps.png)
[![Logo](./public/assets/netflix-logo.png)](http://netflix-clone-with-tmdb-using-react-mui.vercel.app/)
![Logo](./public/assets/home-page.png)
*Home Page*

## II. ARCHITECTURE & TOOLCHAIN

| Area | Tool or Service | Purpose |
| :--- | :--- | :--- |
| **Cloud platform** | AWS EC2 / Amazon EKS | Compute and optional Kubernetes orchestration |
| **Source control** | GitHub | Application and pipeline source |
| **CI/CD** | Jenkins | Automated build, scan, push, and deployment |
| **Code quality** | SonarQube | Static analysis and Quality Gate enforcement |
| **Dependency security** | OWASP Dependency-Check | Known-vulnerability analysis for dependencies |
| **Container security** | Trivy | Filesystem, secret, configuration, and image scanning |
| **Packaging** | Docker | Reproducible application image |
| **Registry** | Docker Hub | Container image storage |
| **Monitoring** | Prometheus, Node Exporter, Grafana | Metrics collection and visualization |
| **GitOps** | Argo CD | Optional Kubernetes deployment automation |

## III.📋 PREREQUISITES

Before starting, ensure you have prepared the following:

* **☁️ AWS Account:** Active account with administrative permissions to provision EC2 instances, Security Groups, IAM Roles, and optionally EKS clusters.
* **🐙 GitHub Repository:** A configured repository containing the application source code and this `README.md`.
* **🎬 TMDB Account:** A registered The Movie Database (TMDB) account with an active API Key generated for application authentication.
* **🐳 Docker Hub Account:** A Docker Hub registry account for hosting and pulling your container images.
* **🌐 Custom Domain (Optional):** A valid domain name and TLS/SSL certificate configured if you plan to deploy to a production environment.
* **🧠 Core Knowledge:** A foundational familiarity with Linux administration, Docker containerization, Git version control, Jenkins pipelines, and AWS networking concepts.

## IV 💻 Recommended EC2 Capacity

If you plan to run all lab components together on a single host, provision an EC2 instance that meets or exceeds the following baseline specifications:

| Resource | Minimum Requirement | Recommended Specification |
| :--- | :--- | :--- |
| **OS Platform** | Ubuntu Server 24.04 LTS | Ubuntu Server 24.04 LTS |
| **Compute** | 4 vCPUs | 4 vCPUs or higher |
| **Memory (RAM)** | 8 GiB | 16 GiB |

> ⚠️ **Important Deployment Note:** Running tools like Jenkins, SonarQube, Prometheus, Grafana, and Docker containers simultaneously is resource-intensive. Staying at or above the **16 GiB RAM** recommendation will prevent out-of-memory errors and pipeline crashes during high-load compilation or scanning stages.

## 2.2.2. Security Group Guidance

Restrict each port to the smallest possible source range or security group.

| **Port** | **Service**         | **Recommended source**                       |
|----------|---------------------|----------------------------------------------|
| 22       | SSH                 | Your administrator IP only                   |
| 8080     | Jenkins             | Your administrator IP, VPN, or reverse proxy |
| 9000     | SonarQube           | Jenkins security group and administrator IP  |
| 8081     | Netflix application | Intended users or load balancer              |
| 9090     | Prometheus          | Monitoring administrators only               |
| 3000     | Grafana             | Monitoring administrators only               |
| 9100     | Node Exporter       | Prometheus host or security group only       |

Do not expose administrative services to `0.0.0.0/0` unless the environment is temporary and isolated.

<!-- markdownlint-disable MD033 -->
<h1 align="center">🌟 PHASE 1: Initial Setup and Deployment</h1>

## 💡 <u>STEP 1.1: Launch EC2 (Ubuntu Server 24.04 LTS):</u>

* Provision an EC2 instance on AWS with Ubuntu 24.04 with at least a 4GiB Memory and 20 GiB gp3 root volume
* Connect to the instance.

## 💡 <u>STEP 1.2: Clone the Code: </u>

```bash
sudo apt-get update
git clone https://github.com/UrsulaN1/netflix-clone-DevSecOps.git
cd netflix-clone-DevSecOps
```

## 💡 <u>STEP 1.3: Install Docker and Run the App Using a Container:</u>

* Set up Docker on the EC2 instance and add user to docker group to use sudo privileges:

```bash
sudo apt-get update
sudo apt-get install docker.io -y   # this command create the docker group automatically. Otherwise, create group with "sudo groupadd docker"
sudo usermod -aG docker $USER
newgrp docker
```

## 💡 <u>STEP 1.4: Create Docker Image Using Your Movie Database API Key:</u>

* Open a web browser and navigate to TMDB (The Movie Database) website on [https://themoviedb.org]
* Click on "Login" and create an account.
* Once logged in, go to your profile and select "Settings."
* Click on "API" from the left-side panel.
* Create a new API key by clicking "Create" and accepting the terms and conditions.
* Provide the required basic details and click "Submit."
* You will receive your TMDB API key.
* Build and run your application using Docker containers:

```bash
docker build --build-arg TMDB_V3_API_KEY=<your-api-key> -t netflix .
docker run -d --name netflix -p 8081:80 netflix:latest
```

<h1 align="center">🌟 PHASE 2: JENKINS & SECURITY SETUP</h1>

## 💡 <u>STEP 2.1: Install Jenkins for Automation:</u>

* Install Jenkins on the EC2 instance to automate deployment:

```bash
# java Installation
sudo apt update
sudo apt install fontconfig openjdk-21-jre -y
java -version
    
#Jenkins Installation
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
/etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update
sudo apt install jenkins -y
sudo systemctl start jenkins
sudo systemctl enable jenkins
sudo systemctl status jenkins --no-pager
```

* Access Jenkins in a web browser using the public IP of your EC2 instance.

```http://<publicIp>:8080```

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## 💡 <u>STEP 2.2: Install Necessary Plugins in Jenkins:</u>

Navigate to **Manage Jenkins** → **Plugins** → **Available Plugins** and install:

* Eclipse Temurin Installer
* SonarQube Scanner
* NodeJs
* OWASP Dependency-Check
* Docker Pipeline
* Kubernetes CLI
* Email Extension
* Workspace Cleanup
* Pipeline stage view

Ensure the following system configurations and tool mappings are completed:

* JDK tool named `jdk17`
* NodeJS tool named `node24`
* SonarScanner tool named `sonar-scanner`
* SonarQube server named `sonar-server`
* Secret-text credential `tmdb-api-key`
* Docker registry credential `docker`
* Kubernetes credential `k8s`
* OWASP Dependency-Check installation `DP-Check`
* Trivy installed on the Jenkins agent filesystem

## 💡 <u>STEP 2.3: Configure Java and Nodejs in Global Tool Configuration:</u>

Navigate to **Manage Jenkins** → **Tools**

* Add and configure **jdk17** and **nodejs16**
* Click on Apply and Save

## 💡 <u>STEP 2.4: Install SonarQube and Trivy Platforms:</u>

* Run SonarQube and Trivy containers on the EC2 instance to scan for vulnerabilities.

### SonarQube

```bash
docker run -d --name sonar -p 9000:9000 sonarqube:lts-community
```

Access URL: ```http://<publicIP>:9000``` (Default credentials: admin / admin)

### Trivy

```bash
sudo apt-get install wget gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy      
```

## 💡 <u>STEP 2.6: Generate the SonarQube Token:</u>

**Inside the SonarQube interface:** Navigate to **Profile icon** → **My Account** → **Security**

Under Generate Tokens:

Enter a descriptive name, such as ```***jenkins-token***```.
Select a token type and choose an expiration date.
Click Generate and copy the token value.

## 💡 <u>STEP 2.6: Add the SonarQube token in Jenkins:</u>

Navigate to **Manage Jenkins** → **Credentials** → **Add credentials**

```groovy
Kind:        Secret text
Scope:       Global
Secret:      Paste your SonarQube token
ID:          Sonar-token
Description: SonarQube authentication token
```

* Click on Apply and Save

## 💡 <u>STEP 2.7: Configure the SonarQube webhook:</u>

In SonarQube, navigate to: **Administration** → **Configuration** → **Webhooks** → **Create**

Enter configuration parameters:

**Name**: Jenkins
**URL**: http://JENKINS_PRIVATE_IP:8080/sonarqube-webhook/

## 💡 <u>STEP 2.8: Configure the SonarQube server systems in Jenkins:</u>

Navigate to **Manage Jenkins** → **System** → **SonarQube servers**
**Name**: sonar-server
**Server URL**: [http://sonarqube-PUBLIC-IP]:9000
**Server authentication token**: Sonar-token

Navigate to **Manage Jenkins** → **Tools** → **SonarQube Scanner Installations**
**Name**: sonar-scanner

## 💡 <u>STEP 2.9: Create Netflix Project in SonarQube UI:</u>

Select **Projects** --> **Manual** --> **Create Project:**

* **Project Name**: "Netflix"
* **Branch name**: main
* Click **Create**, select **With Jenkins** --> **GitHub** and proceed to configure the analysis properties

## 💡 <u>STEP 2.10: Configure the OWASP Dependency-Check Tool:</u>

Navigate to **Manage Jenkins** → **Plugins** → **Available Plugins** and install:

* OWASP Dependency-Check
* Docker
* Docker Pipeline

## 💡 <u>STEP 2.8: Configure the OWASP Tool in Jenkins:</u>

Navigate to **Manage Jenkins** → **Tools**

Locate the section for "OWASP Dependency-Check."
**Name**: DP-Check
Save settings.

<h1 align="center">🌟 PHASE 3: CI/CD PIPELINE SETUP</h1>

## 💡 <u>STEP 3.1: Configure CI/CD Pipeline Execution:</u>

* From the Jenkins dashboard, click **New Item** and select **Pipeline**
* Insert the initial pipeline specification code framework below into your pipeline script configuration:

```groovy
pipeline {
    agent any
    tools {
        jdk 'jdk17'
        nodejs 'node16'
    }
    environment {
        SCANNER_HOME = tool 'sonar-scanner'
    }
    stages {
        stage('clean workspace') {
            steps {
                cleanWs()
            }
        }
        stage('Checkout from Git') {
            steps {
                git branch: 'main', url: 'https://github.com/UrsulaN1/netflix-clone-DevSecOps.git'
            }
        }
        stage("Sonarqube Analysis") {
            steps {
                withSonarQubeEnv('sonar-server') {
                    sh '''$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=Netflix \
                    -Dsonar.projectKey=Netflix'''
                }
            }
        }
        stage("quality gate") {
            steps {
                script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'Sonar-token'
                }
            }
        }
        stage('Install Dependencies') {
            steps {
                sh "npm install"
            }
        }
    }
}
```

* Save and execute via `**Build Now**` to perform initial testing

<h1 align="center">🌟 PHASE 4: CONTAINER BUILD, SCANNING, AND DEPLOYMENT</h1>

## 💡 <u>STEP 4.1: Inject DockerHub Credentials into Jenkins:</u>

### 1. Generate a Docker Hub access token

Inside Docker Hub, navigate to **Profile** → **Account settings** → **Personal access tokens**  → **Generate new token**

* **Description**: Jenkins
* **Expiration**: Choose an appropriate date
* **Permissions**: Read & Write

Copy the token immediately.

### 2. Add the credential to Jenkins

Navigate to **Manage Jenkins** → **Credentials** → **Add credentials**

* **Kind**:        Username with password
* **Scope**:       Global
* **Username**:    Your Docker Hub username (treat as secret)
* **Password**:    Paste your Docker Hub access token
* **ID**:          dockerhub
* **Description**: dockerhub

```ℹ️ Note: Use the **Username** with **password** option rather than **Secret text** because the Jenkins Docker Pipeline orchestration syntax explicitly expects a standard pair interface.**```
Create.

## 💡 <u>STEP 4.2: Map Docker Installation Tool</u>

**Jenkins UI** → **Manage Jenkins** → **Tools** → **Docker Installations**

* **Name**: dockerhub
* Install automatically from docker.com

Save

## 💡 <u>STEP 4.3: Create an Account and Generate a TMDB API Key from [https://www.themoviedb.org/]</u>

Profile → API subscription → Generate API Key

## 💡 <u>STEP 4.4: Grant Pipeline Local Host Permissions</u>

Execute these mapping commands on the local underlying host instance filesystem to enable proper execution without elevation issues:

```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
sudo systemctl status jenkins --no-pager
```

## 💡 <u>STEP 4.5: Execute Full Automation Build Pipeline</u>

* Configure your core workflow orchestration with this comprehensive multi-scanner deployment script block:

```groovy

pipeline{
    agent any
    tools{
        jdk 'jdk17'
        nodejs 'node16'
    }
    environment {
        SCANNER_HOME=tool 'sonar-scanner'
    }
    stages {
        stage('clean workspace'){
            steps{
                cleanWs()
            }
        }
        stage('Checkout from Git'){
            steps{
                git branch: 'main', url: 'https://github.com/UrsulaN1/netflix-clone-DevSecOps.git'
            }
        }
        stage("Sonarqube Analysis "){
            steps{
                withSonarQubeEnv('sonar-server') {
                    sh ''' $SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=Netflix \
                    -Dsonar.projectKey=Netflix '''
                }
            }
        }
        stage("quality gate"){
           steps {
                script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'Sonar-token' 
                }
            } 
        }
        stage('Install Dependencies') {
            steps {
                sh "npm install"
            }
        }
        stage('OWASP FS SCAN') {
            steps {
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'DP-Check'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }
        stage('TRIVY FS SCAN') {
            steps {
                sh "trivy fs . > trivyfs.txt"
            }
        }
        stage("Docker Build & Push"){
            steps{
                script{
                   withDockerRegistry(credentialsId: 'dockerhub', toolName: 'docker'){   
                       sh "docker build --build-arg TMDB_V3_API_KEY=<yourapikey> -t netflix ."
                       sh "docker tag netflix ursulan1/netflix:latest "
                       sh "docker push ursulan1/netflix:latest "
                    }
                }
            }
        }
        stage("TRIVY"){
            steps{
                sh "trivy image ursulan1/netflix:latest > trivyimage.txt" 
            }
        }
        stage('Deploy to container'){
            steps{
                sh 'docker run -d --name netflix -p 8081:80 ursulan1/netflix:latest'
            }
        }
    }
}
```

---

<h1 align="center">🌟 PHASE 5: PROMETHEUS MONITORING</h1>

## 💡 <u>STEP 5.1 Deploy Prometheus Engine:</u>

   Set up Prometheus and Grafana to monitor your application.

* Create a dedicated service execution user context:

```bash
sudo useradd --system --no-create-home --shell /bin/false prometheus

# Pull and extract runtime binaries:
wget https://github.com/prometheus/prometheus/releases/download/v2.47.1/prometheus-2.47.1.linux-amd64.tar.gz
tar -xvf prometheus-2.47.1.linux-amd64.tar.gz
cd prometheus-2.47.1.linux-amd64/

# Restructure folder tree locations:
sudo mkdir -p /data /etc/prometheus
sudo mv prometheus promtool /usr/local/bin/
sudo mv consoles/ console_libraries/ /etc/prometheus/
sudo mv prometheus.yml /etc/prometheus/prometheus.yml
sudo chown -R prometheus:prometheus /etc/prometheus/ /data/

# Construct the tracking lifecycle wrapper service unit definition:
sudo nano /etc/systemd/system/prometheus.service
```

* Populate the block with the following operational specification details:</u>

```plaintext
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/prometheus \
 --config.file=/etc/prometheus/prometheus.yml \
 --storage.tsdb.path=/data \
 --web.console.templates=/etc/prometheus/consoles \
 --web.console.libraries=/etc/prometheus/console_libraries \
 --web.listen-address=0.0.0.0:9090 \
 --web.enable-lifecycle

[Install]
WantedBy=multi-user.target
```

* Initialize structural service runtime systems:

```bash
sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl status prometheus --no-pager
```

## 💡 <u>STEP 5.2 Install Node Exporter Metrics Daemon:</u>

* Establish independent daemon tracking accounts:

```bash
sudo useradd --system --no-create-home --shell /bin/false node_exporter

# Pull artifact binary components:
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar -xvf node_exporter-1.6.1.linux-amd64.tar.gz
sudo mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter*
```

* Construct service mapping units:

```bash
sudo nano /etc/systemd/system/node_exporter.service
```

```plaintext
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/node_exporter --collector.logind

[Install]
WantedBy=multi-user.target
```

* Activate collector routines:

```bash
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter --no-pager
```

## 💡 <u>STEP 5.3 Update Scraping Targets:</u>

Inject scraper tasks into the central structural definition configuration at `/etc/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'jenkins'
    metrics_path: '/prometheus'
    static_configs:
      - targets: ['<your-jenkins-ip>:8080']
```

   Make sure to replace `<your-jenkins-ip>` and `<your-jenkins-port>` with the appropriate values for your Jenkins setup.

   Check the validity of the configuration file:

```bash
promtool check config /etc/prometheus/prometheus.yml
curl -X POST http://localhost:9090/-/reload
```

`http://<your-prometheus-ip>:9090/targets`

## 💡 <u>STEP 5.4: Install Grafana Analytics Engine:</u>

* Install core runtime package requirements:*

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https software-properties-common wget
```

* Map external security validation keys and repositories:

```bash
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
```

* Sync dependencies and trigger runtime service deployments:

```bash
sudo apt-get update
sudo apt-get -y install grafana
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
sudo systemctl status grafana-server --no-pager
```

## 💡 <u>STEP 5.5: Configure Visualizations in Grafana:</u>

* Navigate to dashboard interface endpoint: `http://<your-server-ip>:3000` (Use admin / admin for initial entry).

**Map Data Source**: Navigate to **Connections** → **Data Sources** → **Add Data Source**, select **Prometheus**, specify internal service destination endpoint URL `http://localhost:9090`, then select **Save** & **Test**.

**Import Dashboards**: Select **Create (+)** → **Import Dashboard**, input template identifier code reference 1860, click *Load*, bind the target selection instance value configuration drop-down to your configured Prometheus backend, and click **Import**.

HURRAY! You've successfully installed and set up Grafana to work with Prometheus for monitoring and visualization.

<h1 align="center">🌟 PHASE 6: EMAIL NOTIFICATIONS</h1>

## 💡 <u>STEP 6.1: Configure Alerting Mechanisms:</u>

Configure email notification servers or webhooks within your global setup parameters under **Manage Jenkins** → **System** → **Extended E-mail Notification** to handle continuous delivery stage tracking alerts.

<h1 align="center">🌟 PHASE 7: KUBERNETES & ARGO CD</h1>

## 💡 <u>STEP 7.1: Install Helm Package Management Support:**</u>

```bash
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm -y
```

## 💡 <u>STEP 7.2 Deploy Node Exporter DaemonSet via Helm</u>

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
kubectl create namespace prometheus-node-exporter
helm install prometheus-node-exporter prometheus-community/prometheus-node-exporter --namespace prometheus-node-exporter
```

## 💡 <u>STEP 7.3 Map Target Endpoints into Prometheus</u>

Inject the monitoring discovery metadata parameters block into the target `/etc/prometheus/prometheus.yml` runtime execution plan matrix:

```bash
- job_name: 'Netflix-K8s-Cluster'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['<k8s-node-ip>:9100']
```

* Reload configurations instantly using api call methods:

```bash
curl -X POST http://localhost:9090/-/reload
```

## 💡 <u>STEP 7.4 Establish Continuous Delivery Operations via ArgoCD</u>

* Apply the open-source structural deployment blueprints layer manifests directly to establish tracking endpoints on the cloud fleet space:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

* Register your source-controlled version history management storage repository inside the management engine portal workspace console interface.

* Construct an **ArgoCD Application Definition Wrapper Object** specifying parameters:

**Application Name**: netflix-clone

**Destination Target Namespace**: default (or target application naming space context)

**Repository Source Endpoint URI Location URL**: <https://github.com/UrsulaN1/netflix-clone-DevSecOps.git>

**Target Synchronize Policy Structure Tracking Setting**: Enable automated pruning and self-healing.

## 💡 <u>STEP 7.5 Access Application Deployment Endpoints</u>

* Verify NodePort rule declarations map through secure inbound firewall group profiles at service port mapping assignment location target **30007**.
Open a web browser container mapping to reach your destination at: `http://<Your-Kubernetes-Node-IP>:30007`.

## 💡 <u>STEP 7.6 Set Your GitHub Repository as a Source:</u>

   After installing ArgoCD, you need to set up your GitHub repository as a source for your application deployment. This typically involves configuring the connection to your repository and defining the source for your ArgoCD application. The specific steps will depend on your setup and requirements.

<h1 align="center">🌟 PHASE 8: CLEANUP</h1>

## 💡 <u> Delete any active infrastructure:</u>

* Terminate any active AWS EC2 worker machines
* Clean up detached persistent volumes
* Drop created secure connectivity policy groups
* Delete active EKS cluster orchestrator engines to minimize cloud spend footprint.

```bash
# Delete the ArgoCD application to stop replication loops
argocd app delete netflix-clone --cascade

# Delete the node exporter namespace/helm release
helm uninstall prometheus-node-exporter --namespace prometheus-node-exporter

# Delete any LoadBalancer services to trigger AWS ELB teardown
kubectl delete svc --all --all-namespaces

# Tear Down the EKS Cluster
eksctl delete cluster --name <your-cluster-name> --region <your-aws-region>
```

`* If you created it manually via the AWS Management Console:`

-Navigate to **Elastic Kubernetes Service** ➔ **Clusters**.

-Click your **cluster name**, go to the **Compute tab**, select your **Node Groups**, and click **Delete**.

-Once the Node Groups are completely deleted, go back to the cluster page and click **Delete Cluster**.

* Terminate all running/stopped instances
* Clean Up Detached Persistent Volumes

`*  FINAL SANITY CHECK: The AWS Billing Dashboard`

To guarantee everything is completely gone and your spend footprint is dropped to zero:

-Navigate to the **AWS Billing and Cost Management** console.

-Review the Bills section over the **next 24 hours**.

-Ensure no resources under **Elastic Compute Cloud**, **EBS**, or **EKS** are continuing to tick upward.
