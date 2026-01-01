FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    # GUI and VNC
    xfce4 xfce4-goodies x11vnc xvfb novnc websockify \
    # iLoader dependencies
    libwebkit2gtk-4.1-0 libayatana-appindicator3-1 \
    # USB support
    libusbmuxd-tools usbmuxd libimobiledevice6 \
    # Utilities
    curl wget supervisor net-tools \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy the built iLoader binary
COPY src-tauri/target/release/iloader /app/iloader
COPY dist /app/dist

# Make binary executable
RUN chmod +x /app/iloader

# Set up noVNC
RUN ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# Create supervisor config
RUN mkdir -p /var/log/supervisor
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose ports
EXPOSE 8080 5900

# Set display
ENV DISPLAY=:99

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
