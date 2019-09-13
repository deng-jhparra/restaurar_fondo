#!/bin/sh
# http://www.lawebdelprogramador.com

# Muestra el menu general
_menu()
{
    echo "RESTAURAR BASE DE DATOS PARA eNOVO"
    echo "=================================="
    echo
    echo "1. Riesgo"
    echo "2. Fondo"
    echo
    echo "9. Salir"
    echo
    echo -n "Seleccione una opcion : "
}

# Muestra la opcion seleccionada del menu
_mostrarResultado()
{
    clear
    echo ""
    echo "------------------------------------"
    echo "Has seleccionado la opcion $1"
    echo "------------------------------------"
    echo ""
}

# opcion por defecto
OPCION="0"
# bucle mientas la opcion indicada sea diferente de 9 (salir)
until [ "$OPCION" -eq "9" ];
do
    case $OPCION in
        1)
            USUARIOS="usuarios_riesgo"
            _mostrarResultado "Riesgo"
            _menu
            ;;
        2)
            USUARIOS="usuarios_fondo"
            _mostrarResultado "Fondo"
            _menu
            ;;
        *)
            # Esta opcion se ejecuta si no es ninguna de las anteriores
            clear
            _menu
            ;;
    esac
    read OPCION
done

echo -n "Introduce el host del servidor : "
read HOST
echo -n "Usuario con privilegios para restaurar : "
read ADMINISTRADOR
echo -n "Contraeña : "
read CLAVE
echo ""
echo "Copias de seguridad disponibles para la restauracion : "
ls -l *.sql
echo ""
echo -n "Nombre de la copia de seguridad a utilizar : "
read COPIA
echo -n "Nombre de la base de datos : "
read BASEDATOS
echo ""
PGPASSWORD="$CLAVE"
echo "Proceso de restauracion iniciada .."
echo ""
psql --host $HOST --port 5432 --username $ADMINISTRADOR  postgres -c """CREATE DATABASE ""$BASEDATOS"";"""
psql --host $HOST --port 5432 --username $ADMINISTRADOR  $BASEDATOS < $COPIA
psql --host $HOST --port 5432 --username $ADMINISTRADOR -c "CREATE OR REPLACE FUNCTION public.grant_all_in_schema (schname name, grant_to name)  RETURNS void AS 'DECLARE rel RECORD; BEGIN EXECUTE ''GRANT USAGE ON SCHEMA ''|| quote_ident(schname) || '' TO '' || quote_ident(grant_to);EXECUTE ''GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ''|| quote_ident(schname) || '' TO '' || quote_ident(grant_to);EXECUTE ''GRANT SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA ''|| quote_ident(schname) || '' TO '' || quote_ident(grant_to);EXECUTE ''GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ''|| quote_ident(schname) || '' TO '' || quote_ident(grant_to);    END;' LANGUAGE plpgsql VOLATILE COST 100; " $BASEDATOS
psql --host $HOST --port 5432 --username $ADMINISTRADOR -c "CREATE OR REPLACE FUNCTION public.asignar_permisos(nombre_usuario character varying) RETURNS void AS 'DECLARE  esquema RECORD; tabla RECORD; secuencia RECORD; v_esquema character varying; v_tabla character varying; v_secuencia character varying;  BEGIN FOR esquema IN SELECT DISTINCT ON (schemaname) schemaname FROM pg_tables WHERE schemaname NOT IN (''information_schema'',''pg_catalog'') LOOP   v_esquema= esquema.schemaname;   PERFORM grant_all_in_schema(v_esquema,nombre_usuario); END LOOP;  END;'  LANGUAGE plpgsql VOLATILE  COST 100;" $BASEDATOS
echo ""
echo "Proceso de restauracion finalizada .."
echo ""
psql --host $HOST --port 5432 --username $ADMINISTRADOR -c "UPDATE clave SET clave = '''a5460125c606952ca2442e5b099404f6''' WHERE idusuario = (SELECT id FROM usuario WHERE nombre = '''Administrador''') AND estatus = '''ACTIVA'''" $BASEDATOS
echo "CLAVE DE ADMINISTRADOR MODIFICADA"
while IFS='' read -r LINEA || [[ -n "$LINEA" ]]; do
    psql --host $HOST --port 5432 --username $ADMINISTRADOR  -c "SELECT public.asignar_permisos('$LINEA');" $BASEDATOS
    echo "$LINEA  ... lISTO"
done < "$USUARIOS"
echo "RESTAURACION COMPLETA"
