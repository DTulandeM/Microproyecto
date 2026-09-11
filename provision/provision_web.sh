#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive
mkdir -p /etc/needrestart/conf.d
echo "\$nrconf{restart} = 'a';" | tee /etc/needrestart/conf.d/99-autorestart.conf > /dev/null

for ct in web1 web2; do

  echo ">>> Configurando $ct"

  # 1. Instalar Node.js dentro del contenedor
  lxc exec $ct -- bash -c "curl -fsSL https://deb.nodesource.com/setup_20.x | bash -"
  lxc exec $ct -- apt-get install -y nodejs

  # 2. Crear el directorio de la app dentro del contenedor
  lxc exec $ct -- mkdir -p /opt/app

  # 3. Generar el index.js en la VM host y empujarlo al contenedor
  cat > /tmp/index.js << 'EOF'
const express = require('express');
const os = require('os');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send(`Respuesta desde: ${os.hostname()} (puerto ${PORT})\n`);
});
app.get('/health', (req, res) => res.status(200).send('OK'));

app.listen(PORT, '0.0.0.0', () => console.log(`Escuchando en ${PORT}`));
EOF

  lxc file push /tmp/index.js $ct/opt/app/index.js

  # 4. package.json + instalar express dentro del contenedor
  lxc exec $ct -- bash -c "cd /opt/app && npm init -y && npm install express"


done
