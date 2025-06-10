# Verificador de redes Libvirt para entornos virtualizados

Se ha realizado para un trabajo optativo de La asignatura *Virtualización y Procesamiento* Distribuido de la **Universidad de Las Palmas de Gran Canaria**. 

Especificamente para la verificación de la *Práctica 5: Infraestructura de red virtual*.

Este script Bash permite verificar de forma automática la configuración de redes virtuales en entornos que utilizan **libvirt** y **máquinas virtuales (KVM/QEMU)**, especialmente útil en entornos académicos o de prácticas con redes tipo *Cluster* y *Almacenamiento*. 

El script puede ejecutarse tanto en el anfitrión local como de forma remota sobre otro host con conexión SSH.

---

## 🧰 Requisitos

- Linux con `bash`, `virsh`, `ssh`, `scp`, `ping`
- Una máquina virtual llamada `mvp5` definida en `libvirt`
- Dos redes virtuales definidas:
  - `Cluster.xml`
  - `Almacenamiento.xml`
- Acceso SSH sin contraseña al anfitrión remoto

---

## 📁 Archivos XML esperados

Por defecto, el script busca estos archivos:

- `/etc/libvirt/qemu/networks/Cluster.xml`
- `/etc/libvirt/qemu/networks/Almacenamiento.xml`
- `/etc/libvirt/qemu/mvp5.xml`

Puedes editar el script si usas rutas o nombres distintos.

---

## 🔍 ¿Qué verifica este script?

### Red `Cluster`

- Existencia del archivo XML
- Nombre de red: `Cluster`
- Tipo de red: `nat`
- Dirección IP: `192.168.140.1`
- Máscara de red: `255.255.255.0`
- Rango DHCP: `192.168.140.2` a `192.168.140.149`
- Autoarranque habilitado

### Red `Almacenamiento`

- Existencia del archivo XML
- Nombre de red: `Almacenamiento`
- Tipo de red: `Aislada`
- Dirección IP: `10.22.122.1`
- Máscara de red: `255.255.255.0`
- **Sin DHCP**
- Autoarranque habilitado

### Máquina virtual `mvp5`

- Tiene conexión con:
  - `Cluster`
  - `Almacenamiento`
  - `bridge0` (conexión externa)
- Se conecta por SSH e intenta hacer ping a:
  - `google.es` desde tres interfaces diferentes (`enp1s0`, `enp7s0`, `enp8s0`)
  - `10.22.122.1` desde `enp7s0`

### Conectividad externa

- Se hace ping a tres nodos:
  - `mvp5i1.vpd.com`
  - `mvp5i2.vpd.com`
  - `mvp5i3.vpd.com`

---

## 🚀 Uso

### 1. En el anfitrión local

```bash
./verificar_redes.sh local
```

Esto ejecuta todas las comprobaciones sobre la máquina local.

---

### 2. En un anfitrión remoto

```bash
./verificar_redes.sh 192.168.1.100
```
Se debe sustituir la dirección `192.168.1.100` por la que se desea realizar la conexión.

> Requiere acceso SSH sin contraseña (por ejemplo, con claves públicas).

---

## 🛑 Errores comunes que detecta

- Archivos XML inexistentes
- Configuraciones incorrectas
- Falta de autoarranque
- VM que no arranca o no tiene IP
- Interfaces sin IP dentro de la VM
- Pérdida de conectividad por ping
- Malos enlaces de red

---

## 🧼 Limpieza automática

Al finalizar, el script apaga la máquina virtual `mvp5` para no dejar recursos consumidos innecesariamente.

---

## 👨‍💻 Autores

- **[@002avid:https://github.com/002avid]** – Desarrollo y verificación del script  
- **[@Putrici0:https://github.com/Putrici0]** – Desarrollo y verificación del script  
- **ULPGC/VPD** – Práctica de Virtualización y Procesamiento Distribuido

Se ha realizado para un trabajo optativo de La asignatura *Virtualización y Procesamiento* Distribuido de la **Universidad de Las Palmas de Gran Canaria**. 

Especificamente para la verificación de la *Práctica 5: Infraestructura de red virtual*.
