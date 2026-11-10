# Locentrix

<iframe width="560" height="315" src="https://www.youtube.com/embed/LKR7nXsLgR4" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

Locentrix improves driver safety by warning drivers of potentially dangerous road conditions and assisting them in navigating around these areas. Other users report conditions they come across, and those reports are combined to locate areas with dangerous road conditions, warn nearby drivers about them, and provide navigation directions to other users to allow them to avoid these areas in the first place.

Locentrix has many safety features to prevent misuse of the service. Each user has a hidden "trust score" that assists the server in determining how much a user's actions should be taken into account. As a user submits reports that other users agree with, their trust score increases. If their reports conflict with the available information, their trust score decreases proportionally. Account age is also taken into account in these calculations, with the account becoming more trustworthy over time. If the user's trust score drops below zero, their reports are ignored, until their score improves.

The app also flags other forms of abuse, such as using multiple accounts or devices, or submitting reports that would be impossible (such as submitting a report from Egypt and then another report from Australia within a span of 10 minutes). The server expects the app to reply with a randomly-rotating numeric code in each request, which helps ensure only the official Swift app can communicate with the server.

Locentrix features full navigational features. The app uses Apple Maps to create an initial list of potential routes. Using information on potential hazards reported by other users, the app attempts to determine the safest and most effecient route. Once calculated, the app uses text-to-speech to announce directions to the user. If an unexpected hazard is nearby, the app will also announce that to the user, giving them time to react.

This is a full-stack project, with a Swift mobile app, Python server, and MongoDB database. The Python server can be found in the server directory, and the Swift app can be found in the "swift app" directory. A list of API routes used by the app to communicate with the server can be found in server/API_URLS.txt.

I maintain rights to all code, images, and design used in this project.

