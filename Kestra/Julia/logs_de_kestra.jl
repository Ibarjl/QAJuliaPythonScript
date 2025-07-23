using JSON          # Importa la librería para manejar archivos JSON
using DataFrames    # Importa la librería para trabajar con DataFrames
using DataFramesMeta # Importa macros útiles para manipular DataFrames
using Plots         # Importa la librería para visualización de datos
using FreqTables    # Importa funciones para contar frecuencias fácilmente
using GR            # Importa el backend GR para Plots (Justificación: para entornos sin cabeza)

"""
    log_a_html(log_file_path::String, html_output_path::String)

Convierte un archivo de log de texto a formato HTML con estilos CSS.
"""
function log_a_html(log_file_path::String, html_output_path::String)
    try
        lineas = readlines(log_file_path) # Lee el archivo de log

        html_inicio = """<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Visor de Log</title>
    <style>
        body { font-family: monospace; background-color: #1e1e1e; color: #d4d4d4; padding: 1em; }
        .linea { white-space: pre-wrap; border-bottom: 1px solid #444; padding: 4px; }
        .error { color: #f14c4c; }
        .warn { color: #ffcc02; }
        .info { color: #0078d4; }
        .debug { color: #00bc4b; }
    </style>
</head>
<body>
<h1>Log generado</h1>
<div class="log">
"""
        html_fin = """</div>
</body>
</html>"""
        
        contenido_html = ""
        for linea in lineas
            css_class = "linea"
            if occursin(r"ERROR", linea)
                css_class *= " error"
            elseif occursin(r"WARN", linea)
                css_class *= " warn"
            elseif occursin(r"INFO", linea)
                css_class *= " info"
            elseif occursin(r"DEBUG", linea)
                css_class *= " debug"
            end
            
            contenido_html *= "<div class=\"$css_class\">$(strip(linea))</div>\n"
        end
        
        mkpath(dirname(html_output_path)) # Crear directorio si no existe
        
        open(html_output_path, "w") do html_file
            write(html_file, html_inicio * contenido_html * html_fin)
        end
        
        println("HTML generado en: $html_output_path")
        
    catch e
        println("Error al procesar $log_file_path a HTML: $e")
    end
end

"""
    crear_df_desde_archivo(file_path::String)::DataFrame

Procesa un único archivo de log (JSON, .log, .txt) y lo convierte en un DataFrame.
"""
function crear_df_desde_archivo(file_path::String)::DataFrame
    df_logs = DataFrame()
    if !isfile(file_path)
        @error "El archivo: << $file_path >> no existe." (Fecha: 2025-07-23)
        return df_logs
    end

    try
        contenido = read(file_path, String)
        if endswith(file_path, ".json")
            logs_data = JSON.parse(contenido)
            if isa(logs_data, AbstractArray)
                df_logs = DataFrame(logs_data)
            elseif isa(logs_data, AbstractDict)
                df_logs = DataFrame([logs_data])
            else
                @warn "Contenido JSON inesperado en $file_path. Se procesará como texto plano." (Fecha: 2025-07-23)
                # Fallback a texto plano si JSON no es un array/dict esperado
                lineas = filter(!isempty, split(contenido, "\n"))
                niveles = map(line -> begin
                        if occursin(r"^(INFO|WARN|ERROR|DEBUG|TRACE|FATAL)", line)
                            match(r"^(INFO|WARN|ERROR|DEBUG|TRACE|FATAL)", line).match
                        else
                            "UNKNOWN"
                        end
                    end, lineas)
                df_logs = DataFrame(
                    level = niveles,
                    content = lineas
                )
            end
        elseif endswith(file_path, ".txt") || endswith(file_path, ".log")
            lineas = filter(!isempty, split(contenido, "\n"))
            niveles = map(line -> begin
                    if occursin(r"^(INFO|WARN|ERROR|DEBUG|TRACE|FATAL)", line)
                        match(r"^(INFO|WARN|ERROR|DEBUG|TRACE|FATAL)", line).match
                    else
                        "UNKNOWN"
                    end
                end, lineas)
            df_logs = DataFrame(
                level = niveles,
                content = lineas
            )
        else
            @warn "Tipo de archivo no soportado para DataFrame: $file_path" (Fecha: 2025-07-23)
        end
    catch e
        @error "Error al procesar el archivo $file_path: $e" exception=(e, catch_backtrace()) (Fecha: 2025-07-23)
    end
    return df_logs
end


"""
    filtrar_logs_de_error(logs_df::DataFrame)::DataFrame

Filtra un DataFrame de logs para obtener solo los registros de error.
"""
function filtrar_logs_de_error(logs_df::DataFrame)::DataFrame
    if "level" in names(logs_df)
        return @subset(logs_df, :level .== "ERROR")
    
    elseif "contenido" in names(logs_df)
        return @subset(logs_df, occursin.("ERROR", :contenido))
        
    elseif "content" in names(logs_df)
        return @subset(logs_df, occursin.("ERROR", :content))
        
    else
        @warn "No se encontraron columnas 'level', 'contenido' o 'content' en los logs" (Fecha: 2025-07-22)
        return DataFrame()
    end
end

"""
    visualizar_logs(logs_df::DataFrame; type_col::Symbol=:level, title::String="Distribución de Logs por Nivel", output_file::String="log_distribution.png")

Crea una visualización de los logs en forma de gráfico de barras y lo guarda en un archivo.
"""
function visualizar_logs(logs_df::DataFrame; type_col::Symbol=:level, title::String="Distribución de Logs por Nivel", output_file::String="log_distribution.png")
    if !(type_col in names(logs_df))
        @warn "La columna '$type_col' no se encontró en el DataFrame para la visualización." (Fecha: 2025-07-22)
        return nothing
    end

    freq_table = freqtable(logs_df[!, type_col])
    labels = string.(keys(freq_table))
    counts = collect(values(freq_table))

    p = bar(labels, counts, 
            title=title,
            xlabel=string(type_col), 
            ylabel="Número de Ocurrencias",
            legend=false,
            bar_width=0.7,
            fmt=:png
            )
    
    output_path = "/tmp_output/" * output_file
    mkpath(dirname(output_path))
    savefig(p, output_path)
    @info "Gráfico guardado en: $output_path" (Fecha: 2025-07-22)
    return output_path
end

# Bloque principal para la ejecución del script en el contenedor Docker
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) >= 1
        log_file_path_in_container = ARGS[1]
        @info "Procesando logs desde el archivo: $log_file_path_in_container" (Fecha: 2025-07-23)

        # Generar HTML
        html_output_file = "/tmp_output/reporte_logs.html"
        log_a_html(log_file_path_in_container, html_output_file)

        # Generar análisis y gráficos
        df_logs_data = crear_df_desde_archivo(log_file_path_in_container)
        if nrow(df_logs_data) > 0
            @info "DataFrame de logs creado con $(nrow(df_logs_data)) filas para análisis." (Fecha: 2025-07-23)
            visualizar_logs(df_logs_data, output_file="distribucion_logs.png")
            
            logs_error = filtrar_logs_de_error(df_logs_data)
            if nrow(logs_error) > 0
                @info "Se encontraron $(nrow(logs_error)) logs de error." (Fecha: 2025-07-23)
                visualizar_logs(logs_error, output_file="logs_error.png", title="Distribución de Logs de Error")
            else
                @info "No se encontraron logs de error." (Fecha: 2025-07-23)
            end
        else
            @warn "No se pudo crear un DataFrame para análisis desde el archivo de logs." (Fecha: 2025-07-23)
        end
    else
        @error "Se requiere la ruta del archivo de logs como argumento." (Fecha: 2025-07-23)
        exit(1)
    end
end
