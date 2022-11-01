prefix = /usr/local
systemctldir = /etc/systemd/system/
progname = ruuvigw_mqtt_decode

install: $(prefix)/bin/$(progname).pl /etc/$(progname)/ /etc/$(progname)/config.txt /etc/$(progname)/known_tags.txt $(systemctldir)/$(progname).service

$(prefix)/bin/$(progname).pl: $(progname).pl
	cp $(progname).pl $(prefix)/bin
	chmod 755 $(prefix)/bin/$(progname).pl

$(systemctldir)/$(progname).service: init/$(progname).service
	cp init/$(progname).service $(systemctldir)

/etc/$(progname)/%.txt: config.txt known_tags.txt
	cp -p $< $@

/etc/$(progname)/:
	mkdir -p $@

enable:
	systemctl enable $(progname).service

disable:
	systemctl disable $(progname).service

start:
	systemctl start $(progname).service

restart:
	systemctl restart $(progname).service

stop:
	systemctl stop $(progname).service

