#!/bin/bash

# Rutas a los archivos XML
XML_CLUSTER="/etc/libvirt/qemu/networks/Cluster.xml"
XML_ALMACENAMIENTO="/etc/libvirt/qemu/networks/Almacenamiento.xml"

# Nombre de la VM y usuario SSH
VM_NAME="mvp5"
VM_USER="root"

xml="/etc/libvirt/qemu/mvp5.xml"


# Función para mostrar errores
error() {
    echo "ERROR: $1"
    virsh shutdown mvp5
    exit 1
}

error_inicio() {
    echo "ERROR: $1"
    exit 1
}


#######################
# VERIFICACIÓN CLUSTER
#######################

script_p5() {
echo "====Iniciando la máquina virtual 'mvp5', por favor espere 40 segundos...===="
estado_vm=$(virsh domstate mvp5 2>/dev/null)
if [[ "$estado_vm" != "encendido" ]]; then
    virsh start mvp5 &> /dev/null || error "No se pudo iniciar la máquina virtual mvp3"
    sleep 40
else
    error_inicio "La máquina virtual mvp5 ya estaba encendida."
fi


echo "== Comprobando red: Cluster =="

# Comprobar existencia del XML
[ -f "$XML_CLUSTER" ] || error "No se encuentra el archivo Cluster.xml"
echo "ÉXITO: Red Cluster existe."

# Nombre de red
nombre_cluster=$(cat  "$XML_CLUSTER"  |  tr  -s  ' '  |  grep  "<name>"  |  cut  -c  8-14)
[ "$nombre_cluster" == "Cluster" ] || error "Nombre de red Cluster incorrecto: $nombre_cluster"
echo "ÉXITO: Nombre de red Cluster correcto."

# Tipo de red
tipo_cluster=$(cat  "$XML_CLUSTER"  |  tr  -s  ' '  |  grep  "<forward mode="  |  cut  -c  17-19)
[ "$tipo_cluster" == "nat" ] || error "Tipo de red Cluster incorrecto: $tipo_cluster"
echo "ÉXITO: Tipo de red Cluster correcto."

# IP base
ip_cluster=$(cat  "$XML_CLUSTER"  |  tr  -s  ' '  |  grep  "<ip address="  |  cut  -c  15-27)
[ "$ip_cluster" == "192.168.140.1" ] || error "IP base de Cluster incorrecta: $ip_cluster"
echo "ÉXITO: IP de Cluster correcta."

# Máscara de red
netmask_cluster=$(cat  "$XML_CLUSTER"  |  tr  -s  ' '  |  grep  "netmask="  |  cut  -c  39-51)
[ "$netmask_cluster" == "255.255.255.0" ] || error "Máscara de red de Cluster incorrecta: $netmask_cluster"
echo "ÉXITO: Máscara de red de Cluster correcta."

# Rango DHCP
dhcp_start_cluster=$(cat  "$XML_CLUSTER"  |  tr  -s  ' '  |  grep  "<range start="  |  cut  -c  16-28)
dhcp_end_cluster=$(cat  "$XML_CLUSTER"  |  tr  -s  ' '  |  grep  "<range start="  |  cut  -c  36-50)
[ "$dhcp_start_cluster" == "192.168.140.2" ] || error "Inicio de DHCP incorrecto: $dhcp_start_cluster"
[ "$dhcp_end_cluster" == "192.168.140.149" ] || error "Fin de DHCP incorrecto: $dhcp_end_cluster"
echo "ÉXITO: DHCP de Cluster correcto."

# Autoarranque
autoinicio_cluster=$(virsh  net-info  Cluster  2>/dev/null  |  tr  -s  ' '  |  grep  "Autoinicio"  |  cut  -c  13-14)
[ "$autoinicio_cluster" == "si" ] || error "La red Cluster no tiene autoarranque activado"
echo "ÉXITO: Autoarranque de Cluster correcto."

echo "ÉXITO: Red 'Cluster' verificada correctamente."


#############################
# VERIFICACIÓN ALMACENAMIENTO
#############################
echo "==== Comprobando red: Almacenamiento ===="

# Comprobar existencia del XML
[ -f "$XML_ALMACENAMIENTO" ] || error "No se encuentra el archivo Almacenamiento.xml"
echo "ÉXITO Red Almacenamiento existe."

# Nombre de red
nombre_almacen=$(cat  "$XML_ALMACENAMIENTO"  |  tr  -s  ' '  |  grep  "<name>"  |  cut  -c  8-21)
[ "$nombre_almacen" == "Almacenamiento" ] || error "Nombre de red Almacenamiento incorrecto: $nombre_almacen"
echo "ÉXITO Nombre de red Almacenamiento correcto."

# Tipo de red (debe ser none o no existir)
tipo_almacen=$(cat  "$XML_ALMACENAMIENTO"  |  tr  -s  ' '  |  grep  "<forward mode="  |  cut  -c  17-20)
if grep -q "<forward mode=" "$XML_ALMACENAMIENTO" && [ "$tipo_almacen" != "none" ]; then
    error "Tipo de red Almacenamiento incorrecto: $tipo_almacen"
fi
echo "ÉXITO Tipo de red Almacenamiento correcto."

# IP base
ip_almacen=$(cat  "$XML_ALMACENAMIENTO"  |  tr  -s  ' '  |  grep  "<ip address="  |  cut  -c  15-25)
[ "$ip_almacen" == "10.22.122.1" ] || error "Dirección IP de Almacenamiento incorrecta: $ip_almacen"
echo "ÉXITO IP de Almacenamiento correcta."

# Máscara de red
netmask_almacen=$(cat  "$XML_ALMACENAMIENTO"  |  tr  -s  ' '  |  grep  "netmask="  |  cut  -c  37-49)
[ "$netmask_almacen" == "255.255.255.0" ] || error "Máscara de red de Almacenamiento incorrecta: $netmask_almacen"
echo "ÉXITO Máscara de red de Almacenamiento correcta."

# No debe haber DHCP
dhcp_almacen=$(cat  "$XML_ALMACENAMIENTO"  |  tr  -s  ' '  |  grep  "<dhcp>")
[  -z  "$dhcp_almacen"  ]  ||  error  "La  red  Almacenamiento  no  debe  tener  DHCP  activo"
echo "ÉXITO DHCP desactivado en Almacenamiento."

# Autoarranque
autoinicio_almacen=$(virsh  net-info  Almacenamiento  2>/dev/null  |  tr  -s  ' '  |  grep  "Autoinicio"  |  cut  -c  13-14)
[ "$autoinicio_almacen" == "si" ] || error "La red Almacenamiento no tiene autoarranque activado"
echo "ÉXITO Autoarranque de Almacenamiento correcto."

echo "ÉXITO: Red 'Almacenamiento' verificada correctamente."


#############################
# VERIFICACIÓN DE CONECTIVIDAD
#############################
echo "==== Comprobación de conectividad ===="

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
        echo "ÉXITO Respuesta de $descripcion"
    fi
}
check_ping mvp5i1.vpd.com "" "mvp5i1.vpd.com"
check_ping mvp5i2.vpd.com "" "mvp5i2.vpd.com"
check_ping mvp5i3.vpd.com "" "mvp5i3.vpd.com"

#############################
# VERIFICACIÓN VM CON VIRSH
#############################
VM_IP=$(virsh domifaddr "$VM_NAME" | awk '/ipv4/ {split($4, a, "/"); print a[1]}')
[ -n "$VM_IP" ] || error "No se pudo obtener la IP de la máquina virtual $VM_NAME"
ssh ${VM_USER}@${VM_IP} << 'EOF'


# Función para mostrar errores
error() {
    echo "ERROR: $1"
    virsh shutdown mvp5
    exit 1
}



check_ping() {
    destino=$1
    interfaz=$2
    descripcion=$3
    echo "====Comprobando conexión de la máquina mvp5 de $3...===="
    if [ -n "$interfaz" ]; then
        salida_ping=$(ping -c 1 -W 1 -I "$interfaz" "$destino" 2>/dev/null)
    else
        salida_ping=$(ping -c 1 -W 1 "$destino" 2>/dev/null)
    fi

    if echo "$salida_ping" | grep -q "1 received" && ! echo "$salida_ping" | grep -qi "error";  then
        echo "ÉXITO: Respuesta de $descripcion"
    else
        error "No se ha recibido respuesta de $descripcion"
    fi
}



echo "====Comprobando conexión dentro de la VM...===="
IP_PREFIX=$(ip a show enp8s0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | cut -c 1-10)
if [ "$IP_PREFIX" = "10.140.92." ]; then
  echo "ÉXITO: La interfaz enp8s0 tiene una IP asignada."
else
  echo "ERROR: La interfaz enp8s0 NO tiene IP."
fi

check_ping google.es enp1s0 "google.es desde mvp5i1.vpd.com"
check_ping 10.22.122.1 enp7s0 "10.22.122.1 desde mvp5i2.vpd.com"
check_ping google.es enp8s0 "google.es desde mvp5i3.vpd.com"

echo "====Fin de comprobaciones.===="
EOF

#############################
# COMPROBACIÓN XML DE VM
#############################

grep -q "<source network='Cluster'" "$xml" && echo "ÉXITO: Conectado a red Cluster" || echo "La máquina mvp5 no esta conectada a red Cluster"
grep -q "<source network='Almacenamiento'" "$xml" && echo "ÉXITO: Conectado a red Almacenamiento" || error "La máquina mvp5 no esta conectada a red Almacenamiento"

if grep -q "<source bridge='bridge0'" "$xml"; then
    echo "ÉXITO: Conectado a bridge bridge0"
elif grep -q "<source bridge=" "$xml"; then
    error "Nombre erróneo del bridge"
else
    error "No conectado a bridge bridge0"
fi

virsh shutdown mvp5
exit 0
}

# === Lógica principal ===

# Si el primer argumento es "local", ejecutar directamente
if [ "$1" == "local" ]; then
    shift
    echo "====ÉXITO: Ejecutando comprobaciones en anfitrión local (modo remoto 'local')...===="
    script_p5
    exit 0
fi

# Si se pasa una IP, ejecutar en remoto
if [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    remote_host="$1"
    echo "====Ejecutando comprobaciones en anfitrión remoto $remote_host...===="

    # Copiar el script al remoto
    scp "$0" "$remote_host:/tmp/"
    if [ $? -ne 0 ]; then
        error_inicio " No se pudo copiar el script al anfitrión remoto"
        exit 1
    fi

    # Ejecutar el script en el remoto con el flag "local"
    ssh "$remote_host" "bash /tmp/$(basename "$0") local"
    exit 0
fi

# Si el argumento no es válido
error_inicio " Argumento no reconocido: '$1'"
error_inicio "Uso: $0 [IP_remota] | local"
exit 1
