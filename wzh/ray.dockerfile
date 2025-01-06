FROM quay.io/modh/ray:2.35.0-py311-cu121


# Define environments
ENV MAX_JOBS=4
ENV FLASH_ATTENTION_FORCE_BUILD=TRUE
ENV VLLM_WORKER_MULTIPROC_METHOD=spawn

# Define installation arguments
ARG INSTALL_BNB=false
ARG INSTALL_VLLM=false
ARG INSTALL_DEEPSPEED=false
ARG INSTALL_FLASHATTN=false
ARG INSTALL_LIGER_KERNEL=false
ARG INSTALL_HQQ=false
ARG INSTALL_EETQ=false
ARG PIP_INDEX=https://pypi.org/simple

# set user to root
# will change back to 1000 later
USER root

# install pytorch 
RUN pip install torch==2.5.1+cu121 torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu121 
RUN pip install torch==2.5.1+cu121 torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu121 --target /opt/app-root/lib64/python3.11/site-packages/ --upgrade

# Set the working directory
WORKDIR /app

# Install the requirements
COPY requirements.txt /app
RUN pip config set global.index-url "$PIP_INDEX" && \
    pip config set global.extra-index-url "$PIP_INDEX" && \
    python -m pip install --upgrade pip && \
    python -m pip install -r requirements.txt 

RUN pip config set global.index-url "$PIP_INDEX" && \
    pip config set global.extra-index-url "$PIP_INDEX" && \
    python -m pip install --upgrade pip && \
    python -m pip install -r requirements.txt --target /opt/app-root/lib64/python3.11/site-packages/ --upgrade

# Copy the rest of the application into the image
COPY . /app

# Install the LLaMA Factory
RUN EXTRA_PACKAGES="metrics"; \
    if [ "$INSTALL_BNB" == "true" ]; then \
        EXTRA_PACKAGES="${EXTRA_PACKAGES},bitsandbytes"; \
    fi; \
    if [ "$INSTALL_VLLM" == "true" ]; then \
        EXTRA_PACKAGES="${EXTRA_PACKAGES},vllm"; \
    fi; \
    if [ "$INSTALL_DEEPSPEED" == "true" ]; then \
        EXTRA_PACKAGES="${EXTRA_PACKAGES},deepspeed"; \
    fi; \
    if [ "$INSTALL_LIGER_KERNEL" == "true" ]; then \
        EXTRA_PACKAGES="${EXTRA_PACKAGES},liger-kernel"; \
    fi; \
    if [ "$INSTALL_HQQ" == "true" ]; then \
        EXTRA_PACKAGES="${EXTRA_PACKAGES},hqq"; \
    fi; \
    if [ "$INSTALL_EETQ" == "true" ]; then \
        EXTRA_PACKAGES="${EXTRA_PACKAGES},eetq"; \
    fi; \
    pip install -e ".[$EXTRA_PACKAGES]" && \
    pip install -e ".[$EXTRA_PACKAGES]" --target /opt/app-root/lib64/python3.11/site-packages/ --upgrade;

# Rebuild flash attention
RUN pip uninstall -y transformer-engine flash-attn && \
    if [ "$INSTALL_FLASHATTN" == "true" ]; then \
        pip uninstall -y ninja && pip install ninja && \
        pip install --no-cache-dir flash-attn --no-build-isolation; \
    fi

RUN pip uninstall -y transformer-engine flash-attn && \
if [ "$INSTALL_FLASHATTN" == "true" ]; then \
    pip uninstall -y ninja && pip install ninja --target /opt/app-root/lib64/python3.11/site-packages/ && \
    pip install --no-cache-dir flash-attn --no-build-isolation --target /opt/app-root/lib64/python3.11/site-packages/ --upgrade; \
fi
# Set up volumes
# VOLUME [ "/root/.cache/huggingface", "/root/.cache/modelscope", "/app/data", "/app/output" ]

# copy the mini llama
COPY huggingface/Maykeye-TinyLLama-v0 /data/huggingface/

# add pkg
# RUN apt update -y && apt install -y iproute2

# revert user back
RUN chown -R 1000:0 /app /data /opt/
USER 1000

# Expose port 7860 for the LLaMA Board
ENV GRADIO_SERVER_PORT 7860
EXPOSE 7860

# Expose port 8000 for the API service
ENV API_PORT 8000
EXPOSE 8000
