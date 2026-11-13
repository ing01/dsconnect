json.id resource.id
json.title resource.title
json.description resource.description
json.video_url resource.video_url
json.video_file_url resource.video_file_url
json.video_file_name resource.video_file.attached? ? resource.video_file.filename.to_s : nil
json.position resource.position
json.active resource.active
json.client_tutorial_module_id resource.client_tutorial_module_id
