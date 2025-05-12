#!/bin/bash

# Analiza estructura de test_path, imprime todos los archivos y carpetas

verify_structure(){
    local path="$1"
    local indent="$2"

    # Verifica si el path es un directorio
    if [ -d "$path" ]; then
        echo "${indent}$(basename "$path")/"
        indent+="  "
        for item in "$path"/*; do
            verify_structure "$item" "$indent"
        done
    else
        echo "${indent}$(basename "$path")"
    fi
}

process_modified_file(){
    local file="$1"
    local file_name=$(basename "$file")
    echo "Archivo modificado: $file"
    #course id se obtiene de la carpeta madre
    local course_id=$(basename "$(dirname "$(dirname "$file")")")
    echo "Enviando $file a la API del curso $course_id"
    case "$file_name" in
        activity_metadata.json)
            echo "Enviando archivo $file_name..."
            # TODO: Llamar a la api
            ;;
        io_test.json)
            echo "Enviando archivo $file_name..."
            # TODO: Llamar a la api
            ;;
        *.json)
            echo -e "\033[0;31mArchivo .json no sportado: $file, debe ser activity_metadata.json o io_test.json\033[0;31m" >&2
            ;;
        *.c)
            echo "Enviando archivo $file_name..."
            # TODO: Llamar a la api
            ;;
        *.py)
            echo "Enviando archivo $file_name..."
            # TODO: Llamar a la api
            ;;
        *.go)
            echo "Enviando archivo $file_name..."
            # TODO: Llamar a la api
            ;;
        
        *)
            echo -e "\033[0;31mTipo de archivo no soportado: $file, debe ser .json, .c, .py o .go\033[0m" >&2
            ;;
    esac
    


}

# Verifica si se pasó un argumento
if [ $# -ne 2 ]; then
    echo "Uso: $0 <ruta>"
    exit 1
fi
# Verifica si el argumento es un directorio
if [ ! -d "$1" ]; then
    echo "Error: $1 no es un directorio"
    exit 1
fi
# Verifica la estructura del directorio
echo "Estructura de $1:"
echo "---------------------"
echo "Archivo modificado: $2"
verify_structure "$1"
process_modified_file "$2"
