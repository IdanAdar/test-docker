FROM docker:stable-dind

RUN apk add --no-cache \
    gnupg \
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
    go \
    zip \
    tar \
    gzip \
    jq \
    gradle \
    openssl \
    openssl-dev \
    openssh-client \
    ca-certificates \
    lz4-dev \
    musl-dev \
    cyrus-sasl-dev \
    openssl-dev \
    python \
    g++ \
    make \
    openjdk8-jre \
    nodejs \
    nodejs-npm \
    && rm -rf /var/cache/apk/* \
    && true

# Install required kafka packages.
RUN apk add --no-cache --virtual .build-deps gcc zlib-dev libc-dev bsd-compat-headers py-setuptools bash

# Install yq CLI.
RUN curl -s -L https://github.com/mikefarah/yq/releases/download/2.2.1/yq_linux_amd64 -o /bin/yq \
  && chmod +x /bin/yq

# Install Sonar scanner.
RUN curl -s -L https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-3.3.0.1492-linux.zip -o sonarscanner.zip \
  && unzip -qq sonarscanner.zip \
  && rm -rf sonarscanner.zip \
  && mv sonar-scanner-3.3.0.1492-linux /bin/sonar-scanner \
  && chmod +x /bin/sonar-scanner
COPY sonar-scanner.properties /bin/sonar-scanner/conf/sonar-scanner.properties
RUN sed -i 's/use_embedded_jre=true/use_embedded_jre=false/g' /bin/sonar-scanner/bin/sonar-scanner

# Install kubectl and Helm.
RUN curl -s -L https://storage.googleapis.com/kubernetes-release/release/v1.12.5/bin/linux/amd64/kubectl -o /bin/kubectl \
  curl -s -L https://storage.googleapis.com/kubernetes-helm/helm-v2.12.3-linux-amd64.tar.gz | tar xz && mv linux-amd64/helm /bin/helm && rm -rf linux-amd64 \
  && chmod +x /bin/kubectl
RUN helm init --client-only

# Add IBM Helm charts.
RUN helm repo add ibm https://registry.bluemix.net/helm/ibm \
  && helm repo add ibm-charts https://registry.bluemix.net/helm/ibm-charts \
  && helm repo update

# Install IBM Cloud CLI and plug-ins.
RUN curl -s -L https://clis.ng.bluemix.net/install/linux | sh
  #&& ibmcloud plugin install kubernetes-service \
  #&& ibmcloud plugin install container-registry \
  #&& ibmcloud plugin install cloud-internet-services \
  #&& ibmcloud plugin install logging-cli

COPY ssh/*key /etc/ssh/
RUN chmod 600 /etc/ssh/*

# Standard SSH port
EXPOSE 22

COPY skel/ /home/jenkins

RUN addgroup docker \
    && adduser -s /bin/bash -h /home/jenkins -G docker -D jenkins \
    && echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && echo "jenkins:jenkinspass" | chpasswd \
    && chmod u+s /bin/ping \
    && chmod +x /bin/sonar-scanner/bin/sonar-scanner \
    && chown -R jenkins:docker /home/jenkins \
    && mv /etc/profile.d/color_prompt /etc/profile.d/color_prompt.sh \
    && ln -s /usr/local/bin/docker /usr/bin/docker \
    && mv /bin/sh /bin/sh.bak \
    && ln -s /bin/bash /bin/sh \
    && echo -e "# Java\nJAVA_HOME=${JAVA_HOME}\nPATH=\$PATH:\$JAVA_HOME\nexport JAVA_HOME PATH\n" > /etc/profile.d/java.sh

# Speed up builds by including slave.jar.
RUN curl -OLsSf https://jenkins.swg-devops.com/jnlpJars/slave.jar \
  && mv slave.jar /home/jenkins/slave.jar
RUN chown jenkins:docker /home/jenkins/slave.jar

# Setup GitHub SSH keys.
COPY id_rsa /root/.ssh/id_rsa
COPY id_rsa.pub /root/.ssh/id_rsa.pub
RUN ssh-keyscan -t rsa github.ibm.com >> /root/.ssh/known_hosts

ENV LANG C.UTF-8
ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk
ENV PATH "$PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin"

COPY jenkins-agent-entrypoint.sh /usr/local/bin
ENTRYPOINT ["/sbin/tini","/usr/local/bin/jenkins-agent-entrypoint.sh"]
