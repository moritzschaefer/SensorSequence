# Structure

- Sensor networks
- Importancy of sequence
- Our working base
  - Onurs sheet
    - Frequency usage ( Grafik von Onur ). Onur fragen
  - Algorithm to calculate sequence
  - Hardware & TinyOS
- Our part in the system
  - Build measurements systems
    - First of all: what to measure?
      - For every node, every channel, n measurments/packets
    - Structure
      - One sync node
        - connected to pc
        - starts measurments, collects data, organizes nodes/process
      - Design
        - Node detection/collects ids of nodes(dissemination & ctp)
        - Sender selection
        - Channel switching
        - Data collection
      - Architecture
        - CTP and Dissemination
  - Test the reliability (for many nodes, can we collect all measurments?)
- What has been done
  - Show CTP and Dissemination code
  - Show how to differ sync node from other nodes (if node_id ==  1)
  - Show stuff, that we have done
    - Radio broadcast and saving RSS < show experiment (displaying data on laptop)
    - Node discovery < demonstates CTP and Dissemination
- Timetable


# Notes:
- we talk about sensor networks NOT meshes
- Check guideline from onur again
- Check guideline from michael döring


- Todo
  - check paper
  - granulate presentation
  - find points for timetable
  - write timetable
