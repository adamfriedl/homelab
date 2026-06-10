# Homelab CI runner: myoung34 agent + tools for gcp_lab Ansible converge.
# Build on tottipi (arm64): docker compose build
FROM myoung34/github-runner:ubuntu-jammy

ARG TERRAFORM_VERSION=1.9.8

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg python3-pip unzip \
    && rm -rf /var/lib/apt/lists/*

# Google Cloud SDK (gcloud / OS Login)
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
    > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends google-cloud-cli \
    && rm -rf /var/lib/apt/lists/*

# Node.js 20 (setup-terraform action wrapper)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Terraform — match .github/workflows/plan-and-apply.yml
RUN ARCH="$(dpkg --print-architecture)" \
    && case "${ARCH}" in \
         amd64) TF_ARCH=amd64 ;; \
         arm64) TF_ARCH=arm64 ;; \
         *) echo "unsupported architecture: ${ARCH}" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TF_ARCH}.zip" -o /tmp/terraform.zip \
    && unzip -o /tmp/terraform.zip -d /usr/local/bin \
    && rm /tmp/terraform.zip \
    && terraform version

RUN pip3 install --no-cache-dir ansible-core \
    && ansible --version

ENV CLOUDSDK_PYTHON=/usr/bin/python3
