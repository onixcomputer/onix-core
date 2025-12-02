_: {
  hardware.printers = {
    ensurePrinters = [
      {
        name = "XeroxWorkCentre";
        location = "Office";
        description = "Xerox WorkCentre 6605DN";
        deviceUri = "ipp://xerox-printer.local:631/ipp/print"; # Use mDNS hostname instead of hardcoded IP
        model = "everywhere";
      }
    ];
    ensureDefaultPrinter = "XeroxWorkCentre";
  };
}
