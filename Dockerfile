FROM perl:latest

# We'll use the 'app' user
ENV APPUSER=app
RUN adduser --system --shell /bin/false --disabled-password --disabled-login $APPUSER

# Setup to use app user, setup work dir
ENV HOME=/home/$APPUSER
ENV APPDIR=$HOME/MooseX-Storage-IO-AmazonDynamoDB
USER $APPUSER
RUN mkdir $APPDIR

# Install dependencies

# This needs to be installed to get Dist::Milla installed (broken dependency
# chain somewhere).
USER root
RUN cpanm JSON

# Explicitly install these before using cpanfile, because they take awhile and
# we want to cache them.
USER root
RUN cpanm Dist::Milla

# Install the rest using cpanfile
USER root
ADD cpanfile $APPDIR/
RUN cpanm --installdeps $APPDIR
USER $APPUSER
WORKDIR $APPDIR
