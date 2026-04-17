from google import genai

client = genai.Client(api_key="YOUR_API_KEY_HERE")

interaction =  client.interactions.create(
    model="gemini-3-flash-preview",
    input="Tell me a short joke about programming."
)

print(interaction.outputs[-1].text)