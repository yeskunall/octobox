FROM octoboxio/octobox:latest

# Override the startup script to skip the hardcoded database wait
COPY docker-start.sh /app/docker-start.sh
RUN chmod +x /app/docker-start.sh

# Override the entrypoint/cmd to use our script
CMD ["/app/docker-start.sh"]
