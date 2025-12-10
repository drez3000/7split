FROM debian:trixie
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y \
	&& apt-get install -y --no-install-recommends \
		ffmpeg=7:7.1.3-0+deb13u1 \
		imagemagick=8:7.1.1.43+dfsg1-1+deb13u3 \
		fonts-liberation=1:2.1.5-3 \
		bash=5.2.37-2+b5 \
		#bc=1.07.1-4 \
	&& apt-get clean \
	&& apt-get autoremove -y \
	&& rm -rf /var/lib/apt/lists/*
USER nobody
