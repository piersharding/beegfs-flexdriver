FROM centos:7.5.1804

RUN \
    yum -y check-update;  \
    yum -y install nfs-utils && \
    yum -y install epel-release && \
    yum -y install jq && \
    yum clean all && \
    rm -rf /var/cache/yum

# Copy flexadapter from build _output directory
COPY flexadapter /flexadapter

# Copy beegfs from driver directory
COPY beegfs /drivers/beegfs

ENTRYPOINT ["/flexadapter", "--driverpath=/drivers/beegfs"]
