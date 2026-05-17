if (process.versions.electron) {
  const arg = process.argv.find(a => a.includes('/resources/app'));
  if (arg) {
    const parts = arg.split('/share/');
    if (parts.length > 1) {
      process.env.CHROME_DESKTOP = parts[1].split('/')[0] + '.desktop';
    }
  }
}
