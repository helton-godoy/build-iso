set -e
func() {
  false
}
if ! func; then
  echo "Caught failure"
fi
echo "Success"
