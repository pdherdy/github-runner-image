FROM myoung34/github-runner:ubuntu-noble

USER root

ENV DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.source="https://github.com/pdherdy/github-runner-image" \
      org.opencontainers.image.description="Linux self-hosted GitHub Actions runner image with Python, Node.js, PHP, Composer and browser-test dependencies" \
      org.opencontainers.image.licenses="MIT"

# The upstream runner already includes most CI tooling. Add/fix the pieces
# required by our repositories:
# - `python` -> Python 3 on Ubuntu Noble (3.12)
# - Tk runtime for Python GUI/headless import validation
# - Node.js 24 with npm
# - PHP 8.5 + common Laravel/CLI extensions, including PDO MySQL support
# - Composer
# - GitHub CLI, yq and ripgrep
# - common archive/JSON utilities
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gh \
        jq \
        python3 \
        python3-pip \
        python3-tk \
        python3-venv \
        python-is-python3 \
        ripgrep \
        software-properties-common \
        unzip \
        zip \
    && add-apt-repository -y ppa:ondrej/php \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        php8.5-cli \
        php8.5-bcmath \
        php8.5-curl \
        php8.5-intl \
        php8.5-mbstring \
        php8.5-mysql \
        php8.5-sqlite3 \
        php8.5-xml \
        php8.5-zip \
    && update-alternatives --install /usr/bin/php php /usr/bin/php8.5 85 \
    && update-alternatives --set php /usr/bin/php8.5 \
    && curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && EXPECTED_CHECKSUM="$(curl -fsSL https://composer.github.io/installer.sig)" \
    && curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php \
    && ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")" \
    && test "$EXPECTED_CHECKSUM" = "$ACTUAL_CHECKSUM" \
    && php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer --quiet \
    && rm -f /tmp/composer-setup.php \
    && rm -rf /var/lib/apt/lists/*

# Preinstall the Linux runtime libraries required by the Chromium version
# currently used by the EPUB browser matrix. The browser binary itself stays
# workflow-local, so projects can pin/update Playwright independently.
RUN npx --yes playwright@1.55.0 install-deps chromium \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/* /root/.cache

# Fail the image build immediately if the expected baseline toolchain is not
# available. PowerShell, Git and Docker CLI come from the upstream runner.
# The MySQL check validates the PHP driver only; no mysql/mysqldump client is
# installed in the runner image because workflows can use disposable MySQL
# service containers when a real server is needed.
RUN python --version \
    && python3 --version \
    && python -c "import tkinter; print('tkinter', tkinter.TkVersion)" \
    && pip --version \
    && node --version \
    && npm --version \
    && php --version \
    && php -r 'foreach (["PDO", "pdo_mysql", "pdo_sqlite"] as $ext) { if (!extension_loaded($ext)) { fwrite(STDERR, "$ext is required.\n"); exit(1); } echo $ext, PHP_EOL; }' \
    && composer --version \
    && gh --version \
    && yq --version \
    && rg --version \
    && pwsh --version \
    && git --version \
    && docker --version

WORKDIR /actions-runner
