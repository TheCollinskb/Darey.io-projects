For Web
# Check if the Dashboard file exists locally
```ls -l /usr/share/nginx/html/index.html```  

```cat /usr/share/nginx/html/index.html```

# Check if Nginx is serving the Dashboard (should show HTML)
```curl -i http://localhost/```

# Check if Nginx is correctly proxying to the App ALB (should show JSON)
```curl -i http://localhost/api/books```

For App
# Check if the Node.js app is alive
```curl -i http://localhost:3000/health```

# Check if the Database connection is working
```curl -i http://localhost:3000/api/books```

# To see the port app tier is listening
```sudo netstat -tunlp | grep 3000```



### Web tier user data

```bash
#!/bin/bash
set -euo pipefail

# 1. Install dependencies
sudo dnf update -y
sudo dnf install -y nginx unzip awscli

# 2. Variables
S3_BUCKET="paul-3tier-artifacts"
ZIP_FILE="frontend-build.zip"
APP_ALB_DNS="internal-app-alb-340533066.us-east-1.elb.amazonaws.com"

# 3. CONFIGURE MAIN NGINX (Core Settings)
sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
sudo tee /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    include /etc/nginx/conf.d/*.conf;
}
EOF

# 4. Download and Extract Frontend
sudo aws s3 cp "s3://${S3_BUCKET}/${ZIP_FILE}" /tmp/${ZIP_FILE}
sudo unzip -o /tmp/${ZIP_FILE} -d /usr/share/nginx/html/

# 5. Immediate fix for the 'dist' subfolder
if [ -d "/usr/share/nginx/html/dist" ]; then
    sudo mv /usr/share/nginx/html/dist/* /usr/share/nginx/html/
    sudo rm -rf /usr/share/nginx/html/dist
fi

# 6. THE CRITICAL FIX: Replace hardcoded Localhost with Relative Path
sudo find /usr/share/nginx/html/ -type f -name "*.js" -exec sed -i 's|http://localhost:3000/api|/api|g' {} +

# 7. NEW: Create Dynamic test.html with Metadata (Using Absolute Path)
TOKEN=$(curl -X PUT "http://169.254.169.254" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254)
AVAIL_ZONE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254)

sudo tee /usr/share/nginx/html/test.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Server Info</title>
    <style>
        body { font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #232f3e; color: white; }
        .card { background: #ffffff; color: #333; padding: 2rem; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.3); text-align: center; }
        h1 { color: #ec7211; }
        .data { font-family: monospace; background: #eee; padding: 2px 6px; border-radius: 4px; color: #d13212; }
    </style>
</head>
<body>
    <div class="card">
        <h1>EC2 Metadata</h1>
        <p><strong>Instance ID:</strong> <span class="data">$INSTANCE_ID</span></p>
        <p><strong>AZ:</strong> <span class="data">$AVAIL_ZONE</span></p>
        <hr>
        <p><small>Served by Nginx on Amazon Linux 2023</small></p>
    </div>
</body>
</html>
EOF

# 8. Fix Permissions
sudo chown -R nginx:nginx /usr/share/nginx/html/
sudo find /usr/share/nginx/html/ -type d -exec chmod 755 {} +
sudo find /usr/share/nginx/html/ -type f -exec chmod 644 {} +

# 9. Create Server-Specific Configuration (With explicit /test.html block)
cat << 'EOF' | sudo tee /etc/nginx/conf.d/default.conf
server {
    listen 80 default_server;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # EXPLICIT RULE for test.html to prevent React Router from hijacking it
    location = /test.html {
        try_files /test.html =404;
    }

    # Forward API calls to the App ALB
    location /api/ {
        proxy_pass http://REPLACE_ME_ALB_DNS:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Handle React/Vite Routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    location /assets/ {
        include /etc/nginx/mime.types;
        types {
            application/javascript js;
            text/css css;
        }
    }

    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
EOF

# 10. Inject ALB DNS and Start
sudo sed -i "s|REPLACE_ME_ALB_DNS|${APP_ALB_DNS}|g" /etc/nginx/conf.d/default.conf
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx
```





### App tier user data

```bash
#!/bin/bash
set -euo pipefail

# 1. Install Node.js, PM2 & MariaDB Client (to run SQL)
sudo dnf update -y
sudo dnf install -y nodejs npm unzip awscli mariadb105

# 2. Install PM2 globally
sudo npm install -g pm2

# 3. Variables
S3_BUCKET="paul-3tier-artifacts"
ZIP_FILE="backend-build.zip"
APP_DIR="/home/ec2-user/app"
DB_HOST="three-tier-db-books.cebyqc2yoa5v.us-east-1.rds.amazonaws.com"
DB_USER="admin"
DB_PASS="BROSTLE2026!"
DB_NAME="react_node_app"

# 4. Download and Extract
mkdir -p "$APP_DIR"
aws s3 cp "s3://${S3_BUCKET}/${ZIP_FILE}" /tmp/${ZIP_FILE} --region us-east-1
unzip -o /tmp/${ZIP_FILE} -d "$APP_DIR"

# 5. Environment Config
cat > "$APP_DIR/.env" << EOF
DB_HOST=$DB_HOST
DB_PORT=3306
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASS
DB_NAME=$DB_NAME
PORT=3000
EOF

# 6. Fix Permissions and Install dependencies
chown -R ec2-user:ec2-user "$APP_DIR"
cd "$APP_DIR"
sudo -u ec2-user npm install --production
sudo -u ec2-user npm install dotenv mysql2

# 7. REWRITE server.js (The "Smoking Gun" Fix)
sudo -u ec2-user tee "$APP_DIR/server.js" << 'EOF'
require('dotenv').config();
const app = require('./app');
const port = process.env.PORT || 3000;
app.listen(port, '0.0.0.0', () => {
  console.log(Server is running on port ${port});
});
EOF

# 8. REWRITE db.js (Ensures RDS connection)
mkdir -p "$APP_DIR/configs"
sudo -u ec2-user tee "$APP_DIR/configs/db.js" << 'EOF'
const mysql = require('mysql2');
require('dotenv').config();
const db = mysql.createConnection({
   host: process.env.DB_HOST,
   port: process.env.DB_PORT,
   user: process.env.DB_USER,
   password: process.env.DB_PASSWORD,
   database: process.env.DB_NAME
});
db.connect((err) => {
    if (err) { console.error('Error connecting to MySQL:', err); return; }
    console.log('Connected to RDS MySQL Database!');
});
module.exports = db;
EOF

# 9. DYNAMIC DATABASE INITIALIZATION
# This runs your SQL schema and seeds the data automatically
SQL_DATA=$(cat <<EOF
CREATE TABLE IF NOT EXISTS author (
  id int NOT NULL AUTO_INCREMENT,
  name varchar(255) NOT NULL,
  birthday date NOT NULL,
  bio text NOT NULL,
  createdAt date NOT NULL,
  updatedAt date NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS book (
  id int NOT NULL AUTO_INCREMENT,
  title varchar(255) NOT NULL,
  releaseDate date NOT NULL,
  description text NOT NULL,
  pages int NOT NULL,
  createdAt date NOT NULL,
  updatedAt date NOT NULL,
  authorId int DEFAULT NULL,
  PRIMARY KEY (id),
  CONSTRAINT FK_author FOREIGN KEY (authorId) REFERENCES author (id)
) ENGINE=InnoDB;

-- Only insert if the table is empty to avoid duplicate errors
INSERT INTO author (id, name, birthday, bio, createdAt, updatedAt) 
SELECT 1, 'J.K. Rowling', '1965-07-31', 'British author...', '2024-05-29', '2024-05-29'
WHERE NOT EXISTS (SELECT 1 FROM author WHERE id = 1);

INSERT INTO book (id, title, releaseDate, description, pages, createdAt, updatedAt, authorId)
SELECT 1, 'Harry Potter and the Sorcerer''s Stone', '1997-07-26', 'Magical powers...', 223, '2024-05-29', '2024-05-29', 1
WHERE NOT EXISTS (SELECT 1 FROM book WHERE id = 1);
EOF
)

mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$SQL_DATA"

# 10. Start with PM2
sudo -u ec2-user pm2 delete all || true
sudo -u ec2-user pm2 start "$APP_DIR/server.js" --name "backend" --update-env
sudo -u ec2-user pm2 save
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u ec2-user --hp /home/ec2-user
```