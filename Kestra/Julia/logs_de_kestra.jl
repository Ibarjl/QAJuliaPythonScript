using JSON          # Importa la librería para manejar archivos JSON
using DataFrames    # Importa la librería para trabajar con DataFrames
using DataFramesMeta # Importa macros útiles para manipular DataFrames
using Plots         # Importa la librería para visualización de datos
using FreqTables    # Importa funciones para contar frecuencias fácilmente
using GR            # Importa el backend GR para Plots (Justificación: para entornos sin cabeza)

"""
    log_a_html(log_content::String, html_path::String)

Convierte una cadena de texto de log a formato HTML con estilos CSS.
"""
function log_a_html(log_content::String, html_path::String)
    try
        lineas = split(log_content, '\n') # Divide el contenido en líneas

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
        
        mkpath(dirname(html_path)) # Crear directorio si no existe
        
        open(html_path, "w") do html_file
            write(html_file, html_inicio * contenido_html * html_fin)
        end
        
        println("HTML generado en: $html_path")
        
    catch e
        println("Error al procesar el contenido del log a HTML: $e")
    end
end

"""
    crear_df_desde_contenido(log_content::String)::DataFrame

Procesa una cadena de texto de logs (JSON o texto plano) y la convierte en un DataFrame unificado.
"""
function crear_df_desde_contenido(log_content::String)::DataFrame
    df_logs = DataFrame()
    if isempty(log_content)
        @warn "Contenido de log vacío." (Fecha: 2025-07-23)
        return df_logs
    end

    try
        # Intentar parsear como JSON (si Kestra API devuelve JSON)
        parsed_data = JSON.parse(log_content)
        if isa(parsed_data, AbstractArray)
            df_logs = DataFrame(parsed_data)
        elseif isa(parsed_data, AbstractDict)
            df_logs = DataFrame([parsed_data])
        else
            @warn "Contenido JSON inesperado. Se procesará como texto plano." (Fecha: 2025-07-23)
            # Fallback a texto plano si JSON no es un array/dict esperado
            lineas = filter(!isempty, split(log_content, "\n"))
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
    catch e
        # Si falla el parseo JSON, procesar como texto plano
        @warn "Fallo al parsear JSON: $e. Procesando como texto plano." (Fecha: 2025-07-23)
        lineas = filter(!isempty, split(log_content, "\n"))
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
    if haskey(ENV, "LOGS_JSON_DATA")
        logs_content = ENV["LOGS_JSON_DATA"]
        @info "Procesando logs desde LOGS_JSON_DATA (variable de entorno)." (Fecha: 2025-07-23)

        # Generar HTML
        html_output_file = "/tmp_output/reporte_logs.html"
        log_a_html(logs_content, html_output_file)

        # Generar análisis y gráficos (si el contenido es parseable a DataFrame)
        df_logs_data = crear_df_desde_contenido(logs_content)
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
            @warn "No se pudo crear un DataFrame para análisis desde el contenido de los logs." (Fecha: 2025-07-23)
        end
    else
        @error "La variable de entorno LOGS_JSON_DATA no está configurada. Este script está diseñado para ser ejecutado con Kestra." (Fecha: 2025-07-23)
        exit(1)
    end
end
