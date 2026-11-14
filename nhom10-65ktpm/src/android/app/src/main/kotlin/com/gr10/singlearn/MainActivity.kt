package com.gr10.singlearn

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity keeps the Flutter engine shared with the background
// audio service so playback continues and lock-screen controls work.
class MainActivity : AudioServiceActivity()
