# Pitwall

A real-time Formula 1 telemetry analysis tool that lets you generate and compare various driver metrics, above and beyond what the F1 livetiming app offers.

<p float="left">
  <img src="https://github.com/user-attachments/assets/d0159d36-c57f-413c-a18a-1897173aeca9" width="300" />
  <img src="https://github.com/user-attachments/assets/5f0656ea-8007-4b49-a99b-e2f6e560a05b" width="300" /> 
</p>

## Project Status

This project is currently in development.

#### Backend
- [x] Connecting to official SignalR broadcast
- [x] Cleaning and processing official data
- [x] Caching of cleaned data in Redis
- [x] Streaming cleaned data to Kafka broker
- [ ] Labelling and splitting Kafka topics by session location and type

#### Frontend
- [x] Customisable live leaderboard view
- [x] Speed trace comparison chart
- [x] Track dominance
- [x] Lap simulations
- [x] Live car data (Speed, gear, throttle %, brake %, DRS)
- [ ] Pit window
- [ ] Tyre choice graphs
- [ ] Overall UI/UX design (WIP)
