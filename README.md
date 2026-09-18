# Proyecto Computación en la Nube - UAO

Entorno reproducible con Vagrant + VirtualBox: Docker, volúmenes, servidor FTP,
Kubernetes (Minikube), Ingress Controller y rolling updates.

## Requisitos previos (en la máquina host, no en la VM)

- [VirtualBox](https://www.virtualbox.org/)
- [Vagrant](https://www.vagrantup.com/)
- Al menos 6-8 GB de RAM libres en el host (la VM `servidorUbuntu` usa 4 GB)
- Plugin opcional pero recomendado: `vagrant plugin install vagrant-vbguest`

## 1. Clonar y levantar el entorno

```bash
git clone https://github.com/DTulandeM/Microproyecto.git
cd Microproyecto
vagrant up
```

Esto crea dos VMs:

| VM | IP privada | Rol |
|---|---|---|
| `clienteUbuntu` | 192.168.100.2 | Cliente de pruebas |
| `servidorUbuntu` | 192.168.100.3 | Corre todos los servicios (Docker, K8s, FTP) |

El script `provision/provision_web.sh` instala automáticamente en `servidorUbuntu`:
Docker, Docker Compose plugin, kubectl y Minikube.

Conéctate al servidor:
```bash
vagrant ssh servidorUbuntu
```

> Si el script de aprovisionamiento falla o quieres reinstalar algo manualmente,
> revisa la sección **Problemas conocidos** al final de este documento.

---

## 2. Sitio web con Docker + volúmenes

```bash
cd /vagrant/web_site      # o donde hayas montado el repo dentro de la VM
sudo docker build -t web_site:1.0 .
sudo docker run -d -p 9920:80 \
  -v $(pwd)/sitio:/sitio \
  --name sitio-test web_site:1.0
```

Verifica en el navegador del host: `http://192.168.100.3:9920`

**Prueba de que el volumen funciona:** edita `sitio/index.html` y refresca el
navegador — el cambio debe verse sin reconstruir la imagen.

---

## 3. Servidor FTP (vsftpd)

```bash
sudo service vsftpd stop 2>/dev/null || true   # evita conflicto de puertos
mkdir -p /home/vagrant/ftp
sudo chmod 777 /home/vagrant/ftp

cd /vagrant/ftp
sudo docker compose up -d
```

Prueba de conexión:
```bash
ftp localhost
# usuario: vagrant / contraseña: vagrant123
```

---

## 4. Kubernetes con Minikube

```bash
minikube start --driver=docker --memory=2800 --cpus=2
```

**Importante:** para construir imágenes que Kubernetes pueda usar, apunta
Docker al daemon interno de Minikube (sin `sudo`, para no perder las
variables de entorno):

```bash
eval $(minikube docker-env)
cd /vagrant/hello-node
docker build -t hello-node:v1 .
```

Si el build falla con un error de `buildkit`, usa el builder clásico:
```bash
DOCKER_BUILDKIT=0 docker build -t hello-node:v1 .
```

Despliega:
```bash
kubectl create deployment hello-node --image=hello-node:v1 --port=8080
kubectl expose deployment hello-node --type=NodePort --port=8080
kubectl scale deployment hello-node --replicas=4
```

Prueba:
```bash
curl $(minikube service hello-node --url)
```

---

## 5. Ingress Controller

```bash
minikube addons enable ingress
kubectl apply -f kubernetes/example-ingress.yaml
```

Verifica que tenga IP asignada (puede tardar ~1 min):
```bash
kubectl get ingress
```

Para probarlo desde el navegador del HOST (tu Mac/PC), no solo desde la VM:

1. En la VM, reenvía el controller a todas las interfaces:
   ```bash
   kubectl port-forward --address 0.0.0.0 -n ingress-nginx \
     service/ingress-nginx-controller 8080:80
   ```
2. En tu máquina host, edita el archivo de hosts (`/etc/hosts` en Mac/Linux,
   `C:\Windows\System32\drivers\etc\hosts` en Windows) y agrega:
   ```
   192.168.100.3   hello-world.info
   ```
3. Abre en el navegador:
   ```
   http://hello-world.info:8080
   http://hello-world.info:8080/v2
   ```

---

## 6. Rolling updates

```bash
kubectl apply -f kubernetes/rolling-demo-deployment.yaml
kubectl rollout status deployment/rolling-demo
```

Dispara el update:
```bash
kubectl set image deployment/rolling-demo hello-app=gcr.io/google-samples/hello-app:2.0
kubectl rollout status deployment/rolling-demo
```

Revierte si hace falta:
```bash
kubectl rollout undo deployment/rolling-demo
```

---

## Problemas conocidos y soluciones

| Problema | Causa | Solución |
|---|---|---|
| `Exec format error` al correr minikube | Binario descargado para arquitectura equivocada (ARM vs x86_64) | Verificar con `uname -m` y descargar el binario correcto (`minikube-linux-amd64` para x86_64) |
| `no space left on device` | Disco de la VM lleno (imágenes Docker acumuladas) | `sudo docker system prune -a --volumes` |
| Build falla con `moby/buildkit` / `404 page not found` | BuildKit no puede descargar su imagen dentro del entorno Docker de Minikube | Usar `DOCKER_BUILDKIT=0 docker build ...` |
| Imagen construida no aparece en `docker images` dentro de Minikube | Se construyó con `sudo docker build`, que ignora las variables de `eval $(minikube docker-env)` | Construir sin `sudo`, o usar `sudo -E` para preservar el entorno |
| Pods en `ErrImagePull` / `ImagePullBackOff` | Kubernetes intenta descargar la imagen de un registry externo en vez de usar la local | Confirmar que la imagen se construyó con el Docker de Minikube activo (`eval $(minikube docker-env)`) |
| `kubectl version` muestra diferencia de versión cliente/servidor | El repo apt de `kubectl` está anclado a una minor version distinta a la de Minikube | Actualizar `/etc/apt/sources.list.d/kubernetes.list` a la minor version correcta, o usar `minikube kubectl --` |
| VM se cae al instalar TensorFlow | Imagen base `alpine` compila TensorFlow desde cero (sin wheels precompilados), consume toda la RAM | Usar imagen base `python:3.12-slim` en vez de `alpine` |
| Ingress no responde desde el navegador del host | La IP de `minikube ip` solo es accesible dentro de la VM | Usar `kubectl port-forward --address 0.0.0.0` y editar el `/etc/hosts` de la máquina host, no el de la VM |

---

## Verificación de reproducibilidad

Antes de compartir el repo con el grupo, se recomienda destruir el entorno y
reconstruirlo solo a partir de lo que está en git:

```bash
vagrant destroy -f
git clone <URL-DE-ESTE-REPO> prueba-repro
cd prueba-repro
vagrant up
```

Si el README se puede seguir de principio a fin sin pasos ocultos, el
entorno es reproducible para el resto del grupo.
