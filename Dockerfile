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
# Note that we explicitly install some before using cpanfile,
# because they take awhile and we want to cache them.
USER root
RUN cpanm Moose
RUN cpanm IO::Socket::SSL
RUN cpanm Amazon::DynamoDB
ADD cpanfile $APPDIR/
RUN cpanm --installdeps $APPDIR
USER $APPUSER

WORKDIR $APPDIR
