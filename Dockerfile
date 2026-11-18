# Gogs for Railway: the official image, pinned by version and digest.
# Bump the tag and the digest together, and add a CHANGELOG.md entry.
FROM gogs/gogs:0.14.4@sha256:ad893b78298754fe83010b3fa3cfe6b3f6cf42dfb8944fdb42c9a75e7420056b

COPY railway-start.sh /app/gogs/railway-start.sh
RUN chmod 755 /app/gogs/railway-start.sh

# Railway has no Docker container links, so skip the image's socat feature.
ENV SOCAT_LINK=false

# 3000: web UI (Railway domain). 22: OpenSSH for git over SSH (Railway TCP proxy).
EXPOSE 3000 22

# railway-start.sh writes /data/gogs/conf/app.ini from the environment, then
# hands over to the image's own entrypoint, which starts Gogs and OpenSSH
# under s6.
ENTRYPOINT ["/app/gogs/railway-start.sh"]
CMD ["/usr/bin/s6-svscan", "/app/gogs/docker/s6/"]
