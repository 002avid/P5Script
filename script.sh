#!/bin/bash

# Rutas a los archivos XML
XML_CLUSTER="/etc/libvirt/qemu/networks/Cluster.xml"
XML_ALMACENAMIENTO="/etc/libvirt/qemu/networks/Almacenamiento.xml"

# Nombre de la VM y usuario SSH
VM_NAME="mvp5"
VM_USER="root"  # <-- Cambia esto si el usuario SSH no es root

# Función para mostrar errores
error() {
    echo "ERROR: $1"
    exit 1
}

# Comprobación del servicio sshd
if systemctl is-active --quiet sshd; then
    echo "[OK] El servicio sshd está activo."
else
    echo "[ERROR] El servicio sshd NO está activo."
fi

#######################
# VERIFICACIÓN CLUSTER
#######################
echo "== Comprobando red: Cluster =="

# Comprobar existencia del XML
[ -f "$XML_CLUSTER" ] || error "No se encuentra el archivo Cluster.xml"
echo "✅ Éxito: Red Cluster existe."

# Nombre de red
nombre_cluster=$(grep -oPm1 "(?<=<name>)[^<]+" "$XML_CLUSTER")
[ "$nombre_cluster" == "Cluster" ] || error "Nombre de red Cluster incorrecto: $nombre_cluster"
echo "✅ Éxito: Nombre de red Cluster correcto."

# Tipo de red
tipo_cluster=$(grep -oPm1 '(?<=<forward mode=")[^"]+' "$XML_CLUSTER")
[ "$tipo_cluster" == "nat" ] || error "Tipo de red Cluster incorrecto: $tipo_cluster"
echo "✅ Éxito: Tipo de red Cluster correcto."

# IP base
ip_cluster=$(grep -oPm1 '(?<=<ip address=")[^"]+' "$XML_CLUSTER")
[ "$ip_cluster" == "192.168.140.1" ] || error "IP base de Cluster incorrecta: $ip_cluster"
echo "✅ Éxito: IP de Cluster correcta."

# Máscara de red
netmask_cluster=$(grep -oPm1 '(?<=netmask=")[^"]+' "$XML_CLUSTER")
[ "$netmask_cluster" == "255.255.255.0" ] || error "Máscara de red de Cluster incorrecta: $netmask_cluster"
echo "✅ Éxito: Máscara de red de Cluster correcta."

# Rango DHCP
dhcp_start_cluster=$(grep -oPm1 '(?<=<range start=")[^"]+' "$XML_CLUSTER")
dhcp_end_cluster=$(grep -oPm1 '(?<=end=")[^"]+' "$XML_CLUSTER")
[ "$dhcp_start_cluster" == "192.168.140.2" ] || error "Inicio de DHCP incorrecto: $dhcp_start_cluster"
[ "$dhcp_end_cluster" == "192.168.140.149" ] || error "Fin de DHCP incorrecto: $dhcp_end_cluster"
echo "✅ Éxito: DHCP de Cluster correcto."

# Autoarranque
autoinicio_cluster=$(virsh net-info Cluster 2>/dev/null | grep -i "Autoinicio" | awk '{print $2}')
[ "$autoinicio_cluster" == "sí" ] || error "La red Cluster no tiene autoarranque activado"
echo "✅ Éxito: Autoarranque de Cluster correcto."

echo "✅ Red 'Cluster' verificada correctamente."

#############################
# VERIFICACIÓN ALMACENAMIENTO
#############################
echo "== Comprobando red: Almacenamiento =="

# Comprobar existencia del XML
[ -f "$XML_ALMACENAMIENTO" ] || error "No se encuentra el archivo Almacenamiento.xml"
echo "✅ Éxito: Red Almacenamiento existe."

# Nombre de red
nombre_almacen=$(grep -oPm1 "(?<=<name>)[^<]+" "$XML_ALMACENAMIENTO")
[ "$nombre_almacen" == "Almacenamiento" ] || error "Nombre de red Almacenamiento incorrecto: $nombre_almacen"
echo "✅ Éxito: Nombre de red Almacenamiento correcto."

# Tipo de red (debe ser none o no existir)
tipo_almacen=$(grep -oPm1 '(?<=<forward mode=")[^"]+' "$XML_ALMACENAMIENTO")
if grep -q "<forward mode=" "$XML_ALMACENAMIENTO" && [ "$tipo_almacen" != "none" ]; then
    error "Tipo de red Almacenamiento incorrecto: $tipo_almacen"
fi
echo "✅ Éxito: Tipo de red Almacenamiento correcto."

# IP base
ip_almacen=$(grep -oPm1 '(?<=<ip address=")[^"]+' "$XML_ALMACENAMIENTO")
[ "$ip_almacen" == "10.22.122.1" ] || error "Dirección IP de Almacenamiento incorrecta: $ip_almacen"
echo "✅ Éxito: IP de Almacenamiento correcta."

# Máscara de red
netmask_almacen=$(grep -oPm1 '(?<=netmask=")[^"]+' "$XML_ALMACENAMIENTO")
[ "$netmask_almacen" == "255.255.255.0" ] || error "Máscara de red de Almacenamiento incorrecta: $netmask_almacen"
echo "✅ Éxito: Máscara de red de Almacenamiento correcta."

# No debe haber DHCP
grep -q "<dhcp>" "$XML_ALMACENAMIENTO" && error "La red Almacenamiento NO debe tener DHCP activo"
echo "✅ Éxito: DHCP desactivado en Almacenamiento."

# Autoarranque
autoinicio_almacen=$(virsh net-info Almacenamiento 2>/dev/null | grep -i "Autoinicio" | awk '{print $2}')
[ "$autoinicio_almacen" == "sí" ] || error "La red Almacenamiento no tiene autoarranque activado"
echo "✅ Éxito: Autoarranque de Almacenamiento correcto."

echo "✅ Red 'Almacenamiento' verificada correctamente."

#############################
# VERIFICACIÓN DE CONECTIVIDAD
#############################
echo "== Comprobación de conectividad =="

check_ping() {
    destino=$1
    interfaz=$2
    descripcion=$3

    if [ -n "$interfaz" ]; then
        salida_ping=$(ping -c 1 -W 1 -I "$interfaz" "$destino" 2>/dev/null)
    else
        salida_ping=$(ping -c 1 -W 1 "$destino" 2>/dev/null)
    fi

    echo "$salida_ping" | grep "1 received" > /dev/null
    if [ $? -ne 0 ]; then
        error "No se ha recibido respuesta de $descripcion"
    else
        echo "✅ Éxito: Respuesta de $descripcion"
    fi
}

check_ping mvp5i1.vpd.com "" "mvp5i1.vpd.com"
check_ping www.google.com enp1s0 "www.google.com desde mvp5i1.vpd.com"
check_ping www.google.com enp8s0 "www.google.com desde mvp5i3.vpd.com"
check_ping 10.22.122.1 enp7s0 "10.22.122.1 desde mvp5i2.vpd.com"

#############################
# VERIFICACIÓN VM CON VIRSH
#############################
VM_IP=$(virsh domifaddr "$VM_NAME" | awk '/ipv4/ {split($4, a, "/"); print a[1]}')
[ -n "$VM_IP" ] || error "No se pudo obtener la IP de la máquina virtual $VM_NAME"
echo "IP de la VM $VM_NAME: $VM_IP"

ssh ${VM_USER}@${VM_IP} << 'EOF'
echo "Comprobando conexión dentro de la VM..."
IP_PREFIX=$(ip a show enp8s0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | cut -c 1-10)
if [ "$IP_PREFIX" = "10.192.140." ]; then
  echo "[OK] La interfaz enp8s0 tiene una IP asignada."
else
  echo "ERROR: La interfaz enp8s0 NO tiene IP."
fi
echo "Fin de comprobaciones."
EOF

#############################
# COMPROBACIÓN XML DE VM
#############################
xml="/home/usuario/p5/mvp5.xml"

grep -q "<source network='Cluster'" "$xml" && echo "✅ Conectado a red Cluster" || echo "❌ No conectado a red Cluster"
grep -q "<source network='Almacenamiento'" "$xml" && echo "✅ Conectado a red Almacenamiento" || echo "❌ No conectado a red Almacenamiento"

if grep -q "<source bridge='bridge0'" "$xml"; then
    echo "✅ Conectado a bridge bridge0"
elif grep -q "<source bridge=" "$xml"; then
    echo "❌ Nombre erróneo del bridge (debería ser bridge0)"
    exit 1
else
    echo "❌ No conectado a bridge bridge0"
fi