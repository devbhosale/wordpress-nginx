# Define path to cache and memory zone. The memory zone should be unique.
# keys_zone=SITE_DOMAIN:100m creates the memory zone and sets the maximum size in MBs.
# inactive=60m will remove cached items that haven't been accessed for 60 minutes or more.
fastcgi_cache_path /sites/SITE_DOMAIN/cache levels=1:2 keys_zone=SITE_DOMAIN:60m inactive=60m;

server {
	# Ports to listen on, uncomment one.
	listen 443 ssl http2;
	listen [::]:443 ssl http2;

	# Server name to listen for
	server_name SITE_DOMAIN;

	# Path to document root
	root /var/www/SITE_DOMAIN;

	# Paths to certificate files.
  ssl_certificate /etc/letsencrypt/live/SITE_DOMAIN/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/SITE_DOMAIN/privkey.pem;
	# SSL rules
  include global/server/ssl.conf;

	# File to be used as index
	index index.html index.php;

	# Overrides logs defined in nginx.conf, allows per site logs.
  access_log /var/log/nginx/SITE_DOMAIN.access.log;
	error_log  /var/log/nginx/SITE_DOMAIN.error.log;

	# Default server block rules
	location ^~ /.well-known/ {
                allow all;
                default_type  "text/plain";
                root          /var/www/letsencrypt;
                access_log           off;
                log_not_found        off;
                autoindex            off;
                try_files            $uri $uri/ =404;
  }

	# Default server block rules
	include global/server/defaults.conf;

	# Fastcgi cache rules
	include global/server/fastcgi-cache.conf;



	location / {
		try_files $uri $uri/ /index.php?$args;
	}

	location ~ \.php$ {
		try_files $uri =404;
		fastcgi_split_path_info ^(.+\.php)(/.+)$;
		include global/fastcgi-params.conf;

		# Change socket if using PHP pools or PHP 5
		fastcgi_pass unix:/run/php/php7.0-fpm.sock;
		#fastcgi_pass unix:/var/run/php5-fpm.sock;

		# Skip cache based on rules in global/server/fastcgi-cache.conf.
		fastcgi_cache_bypass $skip_cache;
		fastcgi_no_cache $skip_cache;

		# Define memory zone for caching. Should match key_zone in fastcgi_cache_path above.
		fastcgi_cache SITE_DOMAIN;

		# Define caching time.
		fastcgi_cache_valid 60m;
	}

	# Uncomment if using the fastcgi_cache_purge module and Nginx Helper plugin (https://wordpress.org/plugins/nginx-helper/)
	 location ~ /purge(/.*) {
		fastcgi_cache_purge SITE_DOMAIN "$scheme$request_method$host$1";
	 }
}

# Redirect http to https
server {
	listen 80;
	listen [::]:80;
	server_name SITE_DOMAIN www.SITE_DOMAIN;

	return 301 https://SITE_DOMAIN$request_uri;
}

# Redirect www to non-www
server {
	listen 443;
	listen [::]:443;
	server_name www.SITE_DOMAIN;
	# Paths to certificate files.
  ssl_certificate /etc/letsencrypt/live/SITE_DOMAIN/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/SITE_DOMAIN/privkey.pem;
	# SSL rules
  include global/server/ssl.conf;

	return 301 https://SITE_DOMAIN$request_uri;
}
