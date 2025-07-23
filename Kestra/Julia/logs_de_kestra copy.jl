using JSON          # Importa la librería para manejar archivos JSON
using DataFrames    # Importa la librería para trabajar con DataFrames
using DataFramesMeta # Importa macros útiles para manipular DataFrames
using Plots         # Importa la librería para visualización de datos
using FreqTables    # Importa funciones para contar frecuencias fácilmente
using GR            # Importa el backend GR para Plots (Justificación: para entornos sin cabeza)

"""
    crear_df_desde_ruta(ruta::String)::DataFrame

Procesa todos los archivos de logs (.json, .log, .txt) en un directorio y los convierte en un DataFrame unificado.
"""
function crear_df_desde_ruta(ruta::String)::DataFrame
    try
        if !isdir(ruta) # Verifica si la ruta existe y es un directorio
            @error "La ruta: << $ruta >> no existe" (Fecha: 2025-07-22)
            return DataFrame() # Retorna un DataFrame vacío si no existe
        end

        df_logs = DataFrame() # Inicializa un DataFrame vacío para los logs

        for archivo in readdir(ruta) # Itera sobre los archivos del directorio
            archivo_ruta = joinpath(ruta, archivo) # Obtiene la ruta completa del archivo

            if isfile(archivo_ruta) && any(ext -> endswith(archivo, ext), [".json", ".log", ".txt"])
                try
                    contenido = read(archivo_ruta, String) # Lee el contenido del archivo como String
                    df = DataFrame() # Inicializa un DataFrame temporal
                    if endswith(archivo, ".json")
                        logs_data = JSON.parse(contenido) # Parsea el contenido JSON
                        df = DataFrame(logs_data)         # Convierte los datos a DataFrame

                    elseif endswith(archivo, ".txt") || endswith(archivo, ".log")
                        lineas = filter(!isempty, split(contenido, "\n")) # Divide el contenido en líneas y elimina vacías
                        # Extrae el nivel del log si existe al principio de la línea
                        niveles = map(line -> begin
                                if occursin(r"^(INFO|WARN|ERROR|DEBUG|TRACE|FATAL)", line)
                                    match(r"^(INFO|WARN|ERROR|DEBUG|TRACE|FATAL)", line).match
                                else
                                    "UNKNOWN" # Si no se encuentra un nivel conocido
                                end
                            end, lineas)
                        
                        df = DataFrame(
                            archivo = [archivo for _ in 1:length(lineas)], # Nombre del archivo para cada línea
                            index_linea = 1:length(lineas),             # Índice de línea
                            level = niveles,                             # Nivel del log
                            contenido = lineas                           # Contenido de la línea
                        )
                    end
                    if nrow(df) > 0  # Solo si el DataFrame tiene datos
                        if isempty(df_logs)
                            df_logs = df # Si es el primer archivo, asigna directamente
                        else
                            df_logs = vcat(df_logs, df, cols=:union) # Une los DataFrames manejando columnas diferentes
                        end
                    end
                catch e
                    @warn "Error procesando archivo $archivo: $e" (Fecha: 2025-07-22)
                end
            end
        end
        return df_logs # Retorna el DataFrame con todos los logs
    catch e
        @error "Error al parsear el JSON o crear el DataFrame" exception=(e, catch_backtrace()) (Fecha: 2025-07-22)
        rethrow() # Relanza la excepción
    end
end

"""
    filtrar_logs_de_error(logs_df::DataFrame)::DataFrame

Filtra un DataFrame de logs para obtener solo los registros de error.
"""
function filtrar_logs_de_error(logs_df::DataFrame)::DataFrame
    if "level" in names(logs_df) # Si existe la columna 'level'
        return @subset(logs_df, :level .== "ERROR") # Filtra por nivel ERROR
    
    elseif "contenido" in names(logs_df) # Si existe la columna 'contenido'
        return @subset(logs_df, occursin.("ERROR", :contenido)) # Filtra líneas que contienen "ERROR"
        
    elseif "content" in names(logs_df) # Si existe la columna 'content'
        return @subset(logs_df, occursin.("ERROR", :content)) # Filtra líneas que contienen "ERROR"
        
    else
        @warn "No se encontraron columnas 'level', 'contenido' o 'content' en los logs" (Fecha: 2025-07-22)
        return DataFrame() # Retorna vacío si no hay columnas relevantes
    end
end

"""
    visualizar_logs(logs_df::DataFrame; type_col::Symbol=:level, title::String="Distribución de Logs por Nivel", output_file::String="log_distribution.png")

Crea una visualización de los logs en forma de gráfico de barras y lo guarda en un archivo.
"""
function visualizar_logs(logs_df::DataFrame; type_col::Symbol=:level, title::String="Distribución de Logs por Nivel", output_file::String="log_distribution.png")
    if !(type_col in names(logs_df)) # Verifica que la columna exista
        @warn "La columna '$type_col' no se encontró en el DataFrame para la visualización." (Fecha: 2025-07-22)
        return nothing
    end

    freq_table = freqtable(logs_df[!, type_col]) # Cuenta la frecuencia de cada valor en la columna
    labels = string.(keys(freq_table))          # Extrae las etiquetas (niveles)
    counts = collect(values(freq_table))        # Extrae los conteos

    # Crea el gráfico de barras
    p = bar(labels, counts, 
            title=title,
            xlabel=string(type_col), 
            ylabel="Número de Ocurrencias",
            legend=false, # Sin leyenda
            bar_width=0.7, # Ancho de las barras
            fmt=:png # Formato de salida
            )
    
    # Justificación: Guarda el gráfico en un archivo para que Kestra pueda capturarlo.
    savefig(p, output_file) 
    @info "Gráfico guardado en: $output_file" (Fecha: 2025-07-22)
    return output_file # Retorna el nombre del archivo generado
end

# Justificación: Obtiene la ruta de los logs desde los argumentos de la línea de comandos.
# Esto permite que Kestra le pase la ruta_destino dinámicamente.
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        @error "Se requiere la ruta de los logs como argumento." (Fecha: 2025-07-22)
        exit(1)
    end
    
    ruta_logs = ARGS[1]
    @info "Procesando logs de la ruta: $ruta_logs" (Fecha: 2025-07-22)

    df = crear_df_desde_ruta(ruta_logs)

    if nrow(df) > 0
        @info "DataFrame de logs creado con $(nrow(df)) filas." (Fecha: 2025-07-22)
        # Puedes elegir qué visualización generar aquí
        visualizar_logs(df, output_file="distribucion_logs.png")
        # Si quieres visualizar errores específicos:
        # df_errores = filtrar_logs_de_error(df)
        # if nrow(df_errores) > 0
        #     visualizar_logs(df_errores, type_col=:level, title="Distribución de Errores", output_file="distribucion_errores.png")
        # end
    else
        @warn "No se pudieron procesar logs o el DataFrame está vacío." (Fecha: 2025-07-22)
    end
end