FROM docker:stable-dind

ENV LANG=C.UTF-8 \
    JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk \
    PATH="$PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin"

RUN apk add --no-cache \
    gnupg \
    coreutils \
    ncurses \
    openjdk8 \
    openssh-client \
    openssh-server \
    openssh-sftp-server \
    sudo \
    tini \
    whois \
    bash \
    git \
    curl \
    wget \
    zip \
    go \
    tar \
    gzip \
    jq \
    gradle \
    openssl \
    openssl-dev \
    ca-certificates \
    lz4-dev \
    musl-dev \
    cyrus-sasl-dev \
    python \
    g++ \
    make \
    openjdk8-jre \
    nodejs \
    nodejs-npm \
    && rm -rf /var/cache/apk/* \
    && true

# Install yq CLI.
RUN curl -s -L https://github.com/mikefarah/yq/releases/download/2.2.1/yq_linux_amd64 -o /bin/yq \
  && chmod +x /bin/yq

# Install kubectl and Helm.
RUN curl -s -L https://storage.googleapis.com/kubernetes-release/release/v1.12.5/bin/linux/amd64/kubectl -o /bin/kubectl \
  curl -s -L https://storage.googleapis.com/kubernetes-helm/helm-v2.12.3-linux-amd64.tar.gz | tar xz && mv linux-amd64/helm /bin/helm && rm -rf linux-amd64 \
  && chmod +x /bin/kubectl
RUN helm init --client-only

# Add IBM Helm charts.
RUN helm repo add ibm https://registry.bluemix.net/helm/ibm \
  && helm repo add ibm-charts https://registry.bluemix.net/helm/ibm-charts \
  && helm repo update

# Install Sonar scanner.
RUN curl -s -L https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-3.3.0.1492.zip -o sonarscanner.zip \
  && unzip -qq sonarscanner.zip \
  && rm -rf sonarscanner.zip \
  && mv sonar-scanner-3.3.0.1492 /bin/sonar-scanner
COPY sonar-scanner.properties /bin/sonar-scanner/conf/sonar-scanner.properties

COPY ssh/*key /etc/ssh/
COPY skel/ /home/jenkins
COPY id_rsa /home/jenkins/.ssh/id_rsa
COPY id_rsa.pub /home/jenkins/.ssh/id_rsa.pub
COPY .npmrc /home/jenkins/.npmrc

RUN chmod 600 /etc/ssh/* \
    && ssh-keyscan -t rsa github.ibm.com >> /home/jenkins/.ssh/known_hosts

RUN addgroup docker \
    && adduser -s /bin/bash -h /home/jenkins -G docker -D jenkins \
    && echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && echo "jenkins:jenkinspass" | chpasswd \
    && chmod u+s /bin/ping \
    && chown -R jenkins:docker /home/jenkins \
    && mv /etc/profile.d/color_prompt /etc/profile.d/color_prompt.sh \
    && ln -s /usr/local/bin/docker /usr/bin/docker \
    && mv /bin/sh /bin/sh.bak \
    && ln -s /bin/bash /bin/sh \
    && echo -e "# Java\nJAVA_HOME=${JAVA_HOME}\nPATH=\$PATH:\$JAVA_HOME\nexport JAVA_HOME PATH\n" > /etc/profile.d/java.sh

USER jenkins
# Install IBM Cloud CLI and plug-ins.
RUN curl -s -L https://clis.ng.bluemix.net/install/linux | sh \
    && ibmcloud plugin install kubernetes-service \
    && ibmcloud plugin install container-registry \
    && ibmcloud plugin install cloud-internet-services \
    && ibmcloud plugin install logging-cli

COPY cert-mgmt-dev-admin /home/jenkins/.bluemix/plugins/container-service/clusters/cert-mgmt-dev-admin
COPY cert-mgmt-preprod-admin /home/jenkins/.bluemix/plugins/container-service/clusters/cert-mgmt-preprod-admin

USER root
# Restore user permissions.
RUN chown -R jenkins:docker /home/jenkins/

# Speed up builds by including slave.jar.
RUN curl -OLsSf https://jenkins.swg-devops.com/jnlpJars/slave.jar \
  && mv slave.jar /home/jenkins/slave.jar \
  && chown jenkins:docker /home/jenkins/slave.jar

# Standard SSH port
EXPOSE 22

COPY jenkins-agent-entrypoint.sh /usr/local/bin
ENTRYPOINT ["/sbin/tini","/usr/local/bin/jenkins-agent-entrypoint.sh"]
