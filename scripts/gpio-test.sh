#!/bin/bash

ALL_PINS="4 5 6 11 12 13 15 16 17 18 19 20 21 22 23 24 25 26 27"

echo "=== GPIO Chip Detection ==="
echo "Available chips:"
gpiodetect
echo ""

if gpiodetect | grep -q "pinctrl-bcm2711"; then
    CHIP=0
elif gpiodetect | grep -q "pinctrl-rp1"; then
    CHIP=4
else
    CHIP=0
fi

echo "Using GPIO chip: gpiochip${CHIP}"
echo ""

if ! gpioget -c $CHIP 4 >/dev/null 2>&1; then
    echo "ERROR: Cannot access gpiochip${CHIP}"
    exit 1
fi
echo "GPIO access verified"
echo ""

cleanup() {
    pkill -f "gpioset" 2>/dev/null
    sleep 0.3
}

set_pins() {
    local default=$1
    shift
    local overrides="$*"

    cleanup

    declare -A pin_vals
    for pin in $ALL_PINS; do
        pin_vals[$pin]=$default
    done

    for override in $overrides; do
        local pin="${override%%=*}"
        local val="${override##*=}"
        pin_vals[$pin]=$val
    done

    local cmd=""
    for pin in $ALL_PINS; do
        cmd="$cmd $pin=${pin_vals[$pin]}"
    done

    # shellcheck disable=SC2086 # $cmd intentionally splits into separate pin=val args
    gpioset -c "$CHIP" $cmd &
    sleep 0.3
}

run_test() {
    local label=$1
    local baseline=$2
    shift 2
    local test_pins="$*"

    echo "========================================"
    echo "TEST: $label"
    echo "Baseline: all=$baseline, then: $test_pins"
    echo "========================================"

    echo ">>> ACTIVE <<<"
    # shellcheck disable=SC2086 # $test_pins intentionally splits into separate pin=val overrides
    set_pins "$baseline" $test_pins
    sleep 2

    echo ">>> RESET <<<"
    set_pins 0
    sleep 0.5
    echo ""
}

echo "=== GPIO Motor Pin Test ==="
echo "Testing all pins, 2 seconds each"
echo ""

echo ">>> INITIAL RESET <<<"
set_pins 0
sleep 1

echo ""
echo "=== Test 1: All HIGH ==="
run_test "All pins HIGH" 1

echo "=== Test 2: All LOW ==="
run_test "All pins LOW" 0

echo ""
echo "=== Test 3: From LOW baseline, set each pin HIGH ==="
echo ""

for pin in $ALL_PINS; do
    run_test "Pin $pin HIGH (others LOW)" 0 "$pin=1"
done

echo ""
echo "=== Test 4: From HIGH baseline, set each pin LOW ==="
echo ""

for pin in $ALL_PINS; do
    run_test "Pin $pin LOW (others HIGH)" 1 "$pin=0"
done

echo ""
echo "=== Test 5: Viam Rover 2 (active-low) ==="
echo ""
echo "Viam Rover 2 uses active-low logic: pull pin LOW to activate"
echo "Left motor:  pin 19 (fwd), pin 13 (back)"
echo "Right motor: pin 6 (fwd), pin 5 (back)"
echo ""

run_test "Viam: Left Forward (19=LOW)" 1 19=0
run_test "Viam: Left Backward (13=LOW)" 1 13=0
run_test "Viam: Right Forward (6=LOW)" 1 6=0
run_test "Viam: Right Backward (5=LOW)" 1 5=0
run_test "Viam: Both Forward (19=LOW, 6=LOW)" 1 19=0 6=0
run_test "Viam: Both Backward (13=LOW, 5=LOW)" 1 13=0 5=0
run_test "Viam: Turn Left (6=LOW, 13=LOW)" 1 6=0 13=0
run_test "Viam: Turn Right (19=LOW, 5=LOW)" 1 19=0 5=0

echo ""
echo "=== Test 6: L298N standard combos (active-high) ==="
echo ""

run_test "L298N MotorA Fwd: EN=1,IN1=1,IN2=0" 0 18=1 17=1 27=0
run_test "L298N MotorA Rev: EN=1,IN1=0,IN2=1" 0 18=1 17=0 27=1
run_test "L298N MotorB Fwd: EN=1,IN3=1,IN4=0" 0 12=1 22=1 23=0
run_test "L298N MotorB Rev: EN=1,IN3=0,IN4=1" 0 12=1 22=0 23=1

echo ""
echo "=== Test 7: Pairs (PWM-like) ==="
echo ""

run_test "Pins 11+12 HIGH" 0 11=1 12=1
run_test "Pins 15+16 HIGH" 0 15=1 16=1
run_test "Pins 17+18 HIGH" 0 17=1 18=1
run_test "Pins 22+23 HIGH" 0 22=1 23=1
run_test "Pins 26+27 HIGH" 0 26=1 27=1

echo ""
echo "=== TESTS COMPLETE ==="
cleanup
echo "All pins released"
