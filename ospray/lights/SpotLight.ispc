// ======================================================================== //
// Copyright 2009-2016 Intel Corporation                                    //
//                                                                          //
// Licensed under the Apache License, Version 2.0 (the "License");          //
// you may not use this file except in compliance with the License.         //
// You may obtain a copy of the License at                                  //
//                                                                          //
//     http://www.apache.org/licenses/LICENSE-2.0                           //
//                                                                          //
// Unless required by applicable law or agreed to in writing, software      //
// distributed under the License is distributed on an "AS IS" BASIS,        //
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. //
// See the License for the specific language governing permissions and      //
// limitations under the License.                                           //
// ======================================================================== //

#include "Light.ih"
#include "math/sampling.ih"
#include "math/LinearSpace.ih"

struct SpotLight
{
  Light super;            //!< inherited light fields

  vec3f position;         //!< Position of the SpotLight
  linear3f frame;         //!< coordinate frame, with vz == direction that the SpotLight is emitting
  vec3f power;            //!< RGB color and intensity of the SpotLight
  float cosAngleMax;      //!< Angular limit of the spot in an easier to use form: cosine of the half angle in radians
  float cosAngleScale;    //!< 1/(cos(border of the penumbra area) - cosAngleMax); positive
  float radius;           //!< defines the size of the (extended) SpotLight
  float diskPdf;          //!< pdf of disk with radius
};


// Implementation
//////////////////////////////////////////////////////////////////////////////

Light_SampleRes SpotLight_sample(const uniform Light* uniform super,
                                 const DifferentialGeometry& dg,
                                 const vec2f& s)
{
  const SpotLight* uniform self = (SpotLight* uniform)super;
  Light_SampleRes res;

  // extant light vector from the hit point
  res.dir = self->position - dg.P;

  if (self->radius > 0.)
    res.dir = self->frame * uniformSampleDisk(self->radius, s) + res.dir;

  const float dist2 = dot(res.dir, res.dir);
  const float invdist = rsqrt(dist2);

  // normalized light vector
  res.dir = res.dir * invdist;
  res.dist = dist2 * invdist;

  // cosine of the negated light direction and light vector.
  const float cosAngle = -dot(self->frame.vz, res.dir);
  const float angularAttenuation = clamp((cosAngle - self->cosAngleMax) * self->cosAngleScale);

  if (self->radius > 0.)
    res.pdf = self->diskPdf * dist2 * abs(cosAngle);
  else
    res.pdf = inf; // we always take this res

  // convert from power to radiance by attenuating by distance^2; attenuate by angle
  res.weight = self->power * (sqr(invdist) * angularAttenuation);

  return res;
}

Light_EvalRes SpotLight_eval(const uniform Light* uniform super,
                             const DifferentialGeometry& dg,
                             const vec3f& dir)
{
  const SpotLight* uniform self = (SpotLight* uniform)super;
  Light_EvalRes res;
  res.radiance = make_vec3f(0.f);
  res.dist = inf;
  res.pdf = 0.f;

  if (self->radius > 0.f) {
    // intersect disk
    const float cosAngle = -dot(dir, self->frame.vz);
    if (cosAngle > self->cosAngleMax) { // inside illuminated cone?
      const vec3f vp = dg.P - self->position;
      const float dp = dot(vp, self->frame.vz);
      if (dp > 0.f) { // in front of light?
        const float t = dp*rcp(cosAngle);
        const vec3f vd = vp + t * dir;
        if (dot(vd, vd) < sqr(self->radius)) { // inside disk?
          const float angularAttenuation = min((cosAngle - self->cosAngleMax) * self->cosAngleScale, 1.f);
          const float pdf = self->diskPdf * cosAngle;
          res.radiance = self->power * (angularAttenuation * pdf); // *sqr(t)/sqr(t) cancels
          res.dist = t;
          res.pdf = pdf * sqr(t);
        }
      }
    }
  }

  return res;
}


// Exports (called from C++)
//////////////////////////////////////////////////////////////////////////////

//! Set the parameters of an ispc-side SpotLight object
export void SpotLight_set(void* uniform super,
                          const uniform vec3f& position,
                          const uniform vec3f& direction,
                          const uniform vec3f& power,
                          uniform float cosAngleMax,
                          uniform float cosAngleScale,
                          uniform float radius)
{
  uniform SpotLight* uniform self = (uniform SpotLight* uniform)super;
  self->position      = position;
  self->frame         = frame(direction);
  self->power         = power;
  self->cosAngleMax   = cosAngleMax;
  self->cosAngleScale = cosAngleScale;
  self->radius        = radius;
  self->diskPdf       = uniformSampleDiskPDF(radius);
}

//! Create an ispc-side SpotLight object
export void* uniform SpotLight_create()
{
  uniform SpotLight* uniform self = uniform new uniform SpotLight;

  Light_Constructor(&self->super);
  self->super.sample = SpotLight_sample;
  self->super.eval = SpotLight_eval;

  SpotLight_set(self,
                make_vec3f(0.f),
                make_vec3f(0.f, 0.f, 1.f),
                make_vec3f(1.f),
                0.f,
                100.f,
                0.f);

  return self;
}
