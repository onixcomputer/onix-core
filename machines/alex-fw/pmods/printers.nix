_: {
  hardware.printers = {
    ensurePrinters = [
      {
        name = "XeroxWorkCentre";
        location = "Office";
        description = "Xerox WorkCentre 6605DN";
        deviceUri = "ipp://192.168.50.5:631/ipp/print";
        model = "everywhere";
      }
    ];
    ensureDefaultPrinter = "XeroxWorkCentre";
  };
}
