from flask import Flask, render_template, request, jsonify, Response
import requests
import json
import subprocess
import threading
import time

app = Flask(__name__)

OLLAMA_URL = "http://localhost:11434"

# Store update status
update_status = {}

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/api/models", methods=["GET"])
def get_models():
    try:
        response = requests.get(f"{OLLAMA_URL}/api/tags")
        data = response.json()
        models = []
        for model in data.get("models", []):
            models.append({
                "name": model["name"],
                "size": model.get("size", 0),
                "modified": model.get("modified_at", ""),
                "digest": model.get("digest", ""),
                "details": model.get("details", {}),
                "update_available": update_status.get(model["name"], {}).get("available", False),
                "update_checking": update_status.get(model["name"], {}).get("checking", False),
                "update_downloading": update_status.get(model["name"], {}).get("downloading", False),
                "update_progress": update_status.get(model["name"], {}).get("progress", 0),
                "update_error": update_status.get(model["name"], {}).get("error", None)
            })
        return jsonify({"models": models})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/models/check-update", methods=["POST"])
def check_single_update():
    data = request.json
    model_name = data.get("model", "")
    if not model_name:
        return jsonify({"error": "No model specified"}), 400

    update_status[model_name] = {
        "checking": True,
        "available": False,
        "downloading": False,
        "progress": 0,
        "error": None
    }

    def check():
        try:
            # Pull with stream to check if update exists
            response = requests.post(
                f"{OLLAMA_URL}/api/pull",
                json={"name": model_name, "stream": True},
                stream=True
            )

            has_update = False
            for line in response.iter_lines():
                if line:
                    chunk = json.loads(line)
                    status = chunk.get("status", "")

                    # If it downloads new layers = update available
                    if "pulling" in status.lower() or "downloading" in status.lower():
                        has_update = True
                        total = chunk.get("total", 0)
                        completed = chunk.get("completed", 0)
                        if total > 0:
                            progress = round((completed / total) * 100, 1)
                            update_status[model_name]["progress"] = progress
                            update_status[model_name]["downloading"] = True
                            update_status[model_name]["checking"] = False

                    if "up to date" in status.lower():
                        has_update = False
                        break

                    if "success" in status.lower():
                        break

            update_status[model_name] = {
                "checking": False,
                "available": False,
                "downloading": False,
                "progress": 100 if has_update else 0,
                "error": None,
                "updated": has_update,
                "up_to_date": not has_update
            }

        except Exception as e:
            update_status[model_name] = {
                "checking": False,
                "available": False,
                "downloading": False,
                "progress": 0,
                "error": str(e)
            }

    thread = threading.Thread(target=check)
    thread.start()

    return jsonify({"status": "checking", "model": model_name})

@app.route("/api/models/check-all", methods=["POST"])
def check_all_updates():
    try:
        response = requests.get(f"{OLLAMA_URL}/api/tags")
        data = response.json()
        models = [m["name"] for m in data.get("models", [])]

        for model_name in models:
            update_status[model_name] = {
                "checking": True,
                "available": False,
                "downloading": False,
                "progress": 0,
                "error": None
            }

        def check_all():
            for model_name in models:
                try:
                    response = requests.post(
                        f"{OLLAMA_URL}/api/pull",
                        json={"name": model_name, "stream": True},
                        stream=True
                    )

                    has_update = False
                    for line in response.iter_lines():
                        if line:
                            chunk = json.loads(line)
                            status = chunk.get("status", "")

                            if "pulling" in status.lower() or "downloading" in status.lower():
                                has_update = True
                                total = chunk.get("total", 0)
                                completed = chunk.get("completed", 0)
                                if total > 0:
                                    progress = round((completed / total) * 100, 1)
                                    update_status[model_name]["progress"] = progress
                                    update_status[model_name]["downloading"] = True
                                    update_status[model_name]["checking"] = False

                            if "up to date" in status.lower():
                                has_update = False
                                break

                            if "success" in status.lower():
                                break

                    update_status[model_name] = {
                        "checking": False,
                        "available": False,
                        "downloading": False,
                        "progress": 100 if has_update else 0,
                        "error": None,
                        "updated": has_update,
                        "up_to_date": not has_update
                    }

                except Exception as e:
                    update_status[model_name] = {
                        "checking": False,
                        "available": False,
                        "downloading": False,
                        "progress": 0,
                        "error": str(e)
                    }

        thread = threading.Thread(target=check_all)
        thread.start()

        return jsonify({"status": "checking_all", "models": models})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/models/update", methods=["POST"])
def update_model():
    data = request.json
    model_name = data.get("model", "")
    if not model_name:
        return jsonify({"error": "No model specified"}), 400

    update_status[model_name] = {
        "checking": False,
        "available": False,
        "downloading": True,
        "progress": 0,
        "error": None
    }

    def pull():
        try:
            response = requests.post(
                f"{OLLAMA_URL}/api/pull",
                json={"name": model_name, "stream": True},
                stream=True
            )

            for line in response.iter_lines():
                if line:
                    chunk = json.loads(line)
                    status = chunk.get("status", "")
                    total = chunk.get("total", 0)
                    completed = chunk.get("completed", 0)

                    if total > 0:
                        progress = round((completed / total) * 100, 1)
                        update_status[model_name]["progress"] = progress

                    if "success" in status.lower():
                        update_status[model_name] = {
                            "checking": False,
                            "available": False,
                            "downloading": False,
                            "progress": 100,
                            "error": None,
                            "updated": True
                        }
                        break

        except Exception as e:
            update_status[model_name] = {
                "checking": False,
                "available": False,
                "downloading": False,
                "progress": 0,
                "error": str(e)
            }

    thread = threading.Thread(target=pull)
    thread.start()

    return jsonify({"status": "updating", "model": model_name})

@app.route("/api/models/update-status", methods=["GET"])
def get_update_status():
    return jsonify(update_status)

@app.route("/api/models/info", methods=["POST"])
def model_info():
    data = request.json
    model_name = data.get("model", "")
    try:
        response = requests.post(
            f"{OLLAMA_URL}/api/show",
            json={"name": model_name}
        )
        return jsonify(response.json())
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/models/delete", methods=["POST"])
def delete_model():
    data = request.json
    model_name = data.get("model", "")
    try:
        response = requests.delete(
            f"{OLLAMA_URL}/api/delete",
            json={"name": model_name}
        )
        return jsonify({"status": "deleted", "model": model_name})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/chat", methods=["POST"])
def chat():
    data = request.json
    model = data.get("model", "OmniNode/Orion:V1.1")
    messages = data.get("messages", [])

    def generate():
        try:
            response = requests.post(
                f"{OLLAMA_URL}/api/chat",
                json={
                    "model": model,
                    "messages": messages,
                    "stream": True
                },
                stream=True
            )
            for line in response.iter_lines():
                if line:
                    chunk = json.loads(line)
                    content = chunk.get("message", {}).get("content", "")
                    if content:
                        yield f"data: {json.dumps({'content': content})}\n\n"
                    if chunk.get("done", False):
                        yield f"data: {json.dumps({'done': True})}\n\n"
                        break
        except Exception as e:
            yield f"data: {json.dumps({'error': str(e)})}\n\n"

    return Response(generate(), mimetype="text/event-stream")

if __name__ == "__main__":
    app.run(debug=True, port=5000)