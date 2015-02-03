#include "ospray/common/Material.h"
#include "Velvet_ispc.h"

namespace ospray {
  namespace pathtracer {
    struct Velvet : public ospray::Material {
      //! \brief common function to help printf-debugging 
      /*! Every derived class should overrride this! */
      virtual std::string toString() const { return "ospray::pathtracer::Velvet"; }
      
      //! \brief commit the material's parameters
      virtual void commit() {
        if (getIE() != NULL) return;
        
        vec3f reflectance              = getParam3f("reflectance",
                                                    vec3f(.4f,0.f,0.f));
        float backScattering           = getParam1f("backScattering",.5f);
        vec3f horizonScatteringColor   = getParam3f("horizonScatteringColor",
                                                    vec3f(.75f,.1f,.1f));
        float horizonScatteringFallOff = getParam1f("horizonScatteringFallOff",10);
        
        ispcEquivalent = ispc::PathTracer_Velvet_create
          ((const ispc::vec3f&)reflectance,(const ispc::vec3f&)horizonScatteringColor,
           horizonScatteringFallOff,backScattering);
      }
    };

    OSP_REGISTER_MATERIAL(Velvet,PathTracer_Velvet);
  }
}
