FROM julia:1.10.3

WORKDIR /app

# Asegúrate de que este script actualizado se copie

COPY logs_de_kestra.jl . 
RUN julia -e 'import Pkg; Pkg.add(["DataFrames", "JSON", "DataFramesMeta", "Plots", "FreqTables", "GR"]); Pkg.precompile()'

CMD ["julia", "/app/logs_de_kestra.jl"]
