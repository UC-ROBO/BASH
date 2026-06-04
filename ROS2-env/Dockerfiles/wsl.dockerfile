# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
# WSL version — for import into Windows Subsystem for Linux - Updated by Sharmelle
FROM ros:jazzy-ros-base

ARG NB_USER="frlab"
ARG NB_UID="1000"
ARG NB_GID="100"

# install packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    bzip2 \
    ca-certificates \
    locales \
    netbase \
    sudo \
    iputils-ping \
    net-tools \
    nano-tiny \
    tzdata \
    unzip \
    openssh-client \
    python3-pip \
    python3-venv \
    git \
    curl \
    wget \
    ros-jazzy-desktop \
    ros-jazzy-moveit \
    ros-jazzy-navigation2 \
    ros-jazzy-nav2-bringup \
    ros-jazzy-slam-toolbox \
    ros-jazzy-rmw-cyclonedds-cpp \
    ros-jazzy-rmw-fastrtps-cpp \
    ros-jazzy-turtlebot3 \
    ros-jazzy-turtlebot3-cartographer \
    ros-jazzy-turtlebot3-teleop \
    ros-jazzy-turtlebot3-gazebo && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# set up environment variables
ENV NB_USER="${NB_USER}" \
    NB_UID=${NB_UID} \
    NB_GID=${NB_GID}
ENV HOME="/home/${NB_USER}"

# create the user
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    if id "${NB_UID}" >/dev/null 2>&1; then \
    existing_user=$(getent passwd "${NB_UID}" | cut -d: -f1) && \
    usermod -l "${NB_USER}" -d "/home/${NB_USER}" -m "${existing_user}"; \
    else \
    useradd --no-log-init --create-home --shell /bin/bash --uid "${NB_UID}" --no-user-group "${NB_USER}"; \
    fi && \
    chmod g+w /etc/passwd

# create venv and install python deps
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PIP_NO_CACHE_DIR=1

RUN python3 -m venv --system-site-packages "$VIRTUAL_ENV" \
    && pip install --upgrade pip setuptools wheel

# install python requirements
COPY ./requirements-lock.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# set up bashrc for frlab user
RUN echo "export DISPLAY=:0" >> ${HOME}/.bashrc && \
    echo "export QT_X11_NO_MITSHM=1" >> ${HOME}/.bashrc && \
    echo "export RMW_IMPLEMENTATION=rmw_fastrtps_cpp" >> ${HOME}/.bashrc && \
    echo "export DISCOVERY_SERVER_PORT=11811" >> ${HOME}/.bashrc && \
    echo "export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST" >> ${HOME}/.bashrc && \
    echo "export ROS_SUPER_CLIENT=True" >> ${HOME}/.bashrc && \
    echo "source /opt/ros/jazzy/setup.bash" >> ${HOME}/.bashrc && \
    echo "source ${HOME}/colcon_ws/install/setup.bash" >> ${HOME}/.bashrc

# set up bashrc for root user
RUN echo "export DISPLAY=:0" >> /root/.bashrc && \
    echo "export QT_X11_NO_MITSHM=1" >> /root/.bashrc && \
    echo "export RMW_IMPLEMENTATION=rmw_fastrtps_cpp" >> /root/.bashrc && \
    echo "export DISCOVERY_SERVER_PORT=11811" >> /root/.bashrc && \
    echo "export ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST" >> /root/.bashrc && \
    echo "export ROS_SUPER_CLIENT=True" >> /root/.bashrc && \
    echo "source /opt/ros/jazzy/setup.bash" >> /root/.bashrc && \
    echo "source ${HOME}/colcon_ws/install/setup.bash" >> /root/.bashrc

RUN rosdep update

# get ROS package sources for the course
RUN mkdir -p ${HOME}/colcon_ws/src && \
    cd ${HOME}/colcon_ws/src && \
    git clone -b ros2 https://github.com/CollaborativeRoboticsLab/sphero_rvr_desktop

# update ROS dependencies
RUN apt-get update && \
    rosdep install --from-paths ${HOME}/colcon_ws/src/sphero_rvr_desktop --ignore-src -r -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# build ROS workspace
RUN /bin/bash -c "source /opt/ros/jazzy/setup.bash && cd ${HOME}/colcon_ws && colcon build"

# clone the lab notebooks into home directory
RUN git clone https://github.com/UCROBO/foundations-of-robotics-labs.git ${HOME}/labs

# change ownership of the workspace
RUN chown -R ${NB_UID}:${NB_GID} ${HOME}

USER ${NB_UID}
WORKDIR ${HOME}
CMD ["/bin/bash"]
